FROM node:22-slim AS base

ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
RUN corepack enable && corepack prepare pnpm@latest --activate

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    python3-venv \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g tsx

FROM base AS deps
WORKDIR /app

COPY package.json pnpm-workspace.yaml pnpm-lock.yaml ./
COPY lib/db/package.json ./lib/db/
COPY lib/api-spec/package.json ./lib/api-spec/
COPY lib/api-zod/package.json ./lib/api-zod/
COPY lib/api-client-react/package.json ./lib/api-client-react/
COPY artifacts/api-server/package.json ./artifacts/api-server/
COPY artifacts/tg-bot/package.json ./artifacts/tg-bot/
COPY scripts/package.json ./scripts/

RUN pnpm install --frozen-lockfile

FROM deps AS build
WORKDIR /app

COPY lib/ ./lib/
COPY artifacts/ ./artifacts/
COPY scripts/ ./scripts/

RUN pnpm --filter @workspace/api-server build

RUN pnpm --filter @workspace/tg-bot deploy /app/bot-deploy --prod

FROM base AS runner
WORKDIR /app

ARG SERVICE=bot

COPY --from=build /app/artifacts/api-server/dist ./artifacts/api-server/dist
COPY --from=build /app/node_modules ./node_modules

COPY --from=build /app/bot-deploy/node_modules ./artifacts/tg-bot/node_modules
COPY artifacts/tg-bot/ ./artifacts/tg-bot/
COPY lib/ ./lib/

RUN mkdir -p /app/artifacts/projects

ENV NODE_ENV=production
ENV PORT=8080
ENV SERVICE=${SERVICE}

EXPOSE 8080

CMD sh -c '\
  if [ "$SERVICE" = "api" ]; then \
    exec node --enable-source-maps /app/artifacts/api-server/dist/index.mjs; \
  else \
    exec tsx /app/artifacts/tg-bot/src/index.ts; \
  fi'
