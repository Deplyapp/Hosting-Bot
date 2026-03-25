# HostBot — Telegram Cloud Hosting Bot

A Telegram bot that lets users deploy and manage live projects directly from a chat. Upload a file or ZIP archive and the bot runs it instantly — Python scripts, HTML pages, Node.js apps, Shell scripts, or Docker containers.

---

## Features

- **One-tap deploy** — send a file or `.zip` and the bot detects the type and runs it
- **Supported project types:**
  - 🐍 Python `.py` — runs with `python3`
  - 🌐 HTML `.html` — served via a built-in HTTP server with a public URL
  - 🟨 Node.js `.js` — runs with `node`
  - 🐚 Shell `.sh` — runs with `bash`
  - 🐳 Docker `Dockerfile` or ZIP — builds and runs the container
- **Project management** — start, stop, restart any project from inline buttons
- **Real-time logs** — view up to 300 lines of stdout/stderr output per project
- **Send commands** — pipe text input to a running process's stdin
- **Environment variables** — set, update, and remove per-project env vars; changes apply on restart
- **Auto-install Python packages** — if a Python project crashes with a missing module error, the bot detects it and offers a one-tap auto-install
- **Public URLs** — HTML and Docker projects get a public URL automatically
- **Persistent storage** — project state survives bot restarts via PostgreSQL
- **Per-user isolation** — each user's projects are stored in a separate directory

---

## Tech Stack

| Layer | Technology |
|---|---|
| Language | TypeScript (Node.js 22) |
| Bot framework | [Telegraf 4](https://telegrafjs.org) |
| Database | PostgreSQL (via `pg`) |
| Runtime | `tsx` (runs TypeScript directly) |
| Package manager | `pnpm` (monorepo) |
| Container | Docker |

---

## Project Structure

```
├── Dockerfile              # Single Dockerfile for both bot and API (SERVICE env var switches)
├── docker-compose.yml      # Run both services locally
├── render.yaml             # One-click Render.com deployment
├── artifacts/
│   ├── tg-bot/             # Telegram bot
│   │   └── src/
│   │       ├── index.ts    # Bot logic, commands, inline menus
│   │       ├── runner.ts   # Process manager (start/stop/logs/ports)
│   │       └── database.ts # PostgreSQL queries
│   └── api-server/         # Express REST API (optional companion)
│       └── src/
│           ├── app.ts
│           └── index.ts
└── lib/
    ├── db/                 # Shared Drizzle ORM schema
    ├── api-zod/            # Zod-validated API types
    └── api-spec/           # OpenAPI spec
```

---

## Environment Variables

| Variable | Required | Description |
|---|---|---|
| `TELEGRAM_BOT_TOKEN` | Yes | Bot token from [@BotFather](https://t.me/BotFather) |
| `DATABASE_URL` | Yes | PostgreSQL connection string |
| `SERVICE` | Docker only | `bot` to run the Telegram bot, `api` to run the API server |
| `PORT` | API only | Port for the API server (default `8080`) |

---

## Local Setup

### Prerequisites

- Node.js 22+
- pnpm (`npm install -g pnpm`)
- PostgreSQL database
- A Telegram bot token from [@BotFather](https://t.me/BotFather)

### Steps

```bash
# 1. Clone the repo
git clone https://github.com/Deplyapp/Hosting-Bot.git
cd Hosting-Bot

# 2. Install dependencies
pnpm install

# 3. Create environment file
cp .env.example .env
# Edit .env and fill in TELEGRAM_BOT_TOKEN and DATABASE_URL

# 4. Run the bot
cd artifacts/tg-bot
pnpm start
```

---

## Docker Setup (Local)

```bash
# Copy and fill in your environment variables
cp .env.example .env

# Run both the bot and API
docker compose up --build

# Or run just the bot
docker compose up bot --build

# Or run just the API
docker compose up api --build
```

The single `Dockerfile` handles both services. The `SERVICE` environment variable controls which one runs:

```bash
# Build once
docker build -t hosting-bot .

# Run as bot
docker run -e SERVICE=bot -e TELEGRAM_BOT_TOKEN=... -e DATABASE_URL=... hosting-bot

# Run as API server
docker run -e SERVICE=api -e PORT=8080 -e DATABASE_URL=... -p 8080:8080 hosting-bot
```

---

## Deploy to Render

1. Push this repo to GitHub
2. Go to [render.com](https://render.com) → **New** → **Blueprint**
3. Connect your GitHub repo — Render will read `render.yaml` and create both services automatically
4. Set the secret environment variables in the Render dashboard:
   - `TELEGRAM_BOT_TOKEN`
   - `DATABASE_URL` (use Render's managed PostgreSQL or an external provider like [Neon](https://neon.tech))
5. Deploy

> The bot runs as a **Background Worker** and the API runs as a **Web Service** — both use the same Docker image, switched by the `SERVICE` variable.

---

## Deploy to Koyeb

1. Go to [koyeb.com](https://koyeb.com) → **Create Service** → **GitHub**
2. Select this repo and set **Dockerfile path** to `./Dockerfile`
3. Create **two services**:

   | Service name | SERVICE | Extra env vars |
   |---|---|---|
   | `tg-bot` | `bot` | `TELEGRAM_BOT_TOKEN`, `DATABASE_URL` |
   | `api-server` | `api` | `DATABASE_URL`, `PORT=8080` |

4. Deploy both services

---

## Bot Commands & Navigation

All navigation is done through inline buttons. Start the bot with `/start`.

| Button | Action |
|---|---|
| 🚀 Deploy New Project | Upload a file to deploy |
| 📋 My Projects | List all your projects |
| ▶️ Start | Start a stopped project |
| ⏹️ Stop | Stop a running project |
| 🔄 Restart | Restart a project (picks up new env vars) |
| 📋 Logs | View the last 300 lines of output |
| 🔑 Env Vars | Add, update, or remove environment variables |
| ⌨️ Send Command | Send a line of text to the process stdin |
| 🗑️ Delete | Remove the project and its files |

---

## Database Schema

The bot auto-creates its tables on first run. No migrations needed.

```sql
-- Stores all deployments
CREATE TABLE deployments (
  id TEXT PRIMARY KEY,
  user_id BIGINT NOT NULL,
  name TEXT NOT NULL,
  type TEXT NOT NULL,           -- python | html | nodejs | shell | docker
  status TEXT NOT NULL,         -- running | stopped | error
  port INTEGER,
  file_path TEXT NOT NULL,
  entry_file TEXT,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
);

-- Per-project environment variables
CREATE TABLE deployment_envs (
  id SERIAL PRIMARY KEY,
  deployment_id TEXT REFERENCES deployments(id) ON DELETE CASCADE,
  key TEXT NOT NULL,
  value TEXT NOT NULL,
  UNIQUE(deployment_id, key)
);
```

---

## License

MIT
