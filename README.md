# AI Platform Self-Deploy Kit

Open WebUI + NewAPI + PostgreSQL + Cloudflare Tunnel, with an optional host-side
HTTP proxy, image playground, and xui side stack.

The repository is now organized as a deployable template. Public files are safe
to push to GitHub; private server notes and backups are ignored by git.

## Architecture

```text
Cloudflare Edge
  -> cloudflared
     -> chat.*  -> open-webui:8080
     -> admin.* -> newapi:3000
     -> api.*   -> newapi:3000

open-webui -> newapi -> postgres
newapi/open-webui -> host.docker.internal:7890 -> host proxy -> upstream LLMs
```

The default stack contains only the core AI platform. Optional services are
split into separate compose files so a new server can boot without live-server-specific
networks or credentials.

## Files

| File | Purpose |
|---|---|
| `docker-compose.yml` | Core AI platform: Postgres, NewAPI, Open WebUI, cloudflared, optional Playwright profile |
| `docker-compose.image.yml` | Optional image playground + Caddy public image site |
| `docker-compose.xui-tunnel.yml` | Optional override to attach cloudflared to the xui network |
| `xui/docker-compose.yml` | Optional 3x-ui/Xray stack |
| `.env.example` | Public environment template; copy to `.env` |
| `scripts/install-server.sh` | Fresh-server bootstrap script |
| `backup/pg_dump.sh` | PostgreSQL logical backup script |
| `systemd/ai-proxy-firewall.*` | Bridge-only firewall rule for host proxy access |
| `systemd/proxy-healthcheck.sh` | Host proxy liveness check |
| `AUTO-DEPLOY-PUBLIC.md` | GitHub-safe deployment runbook |
| `AUTO-DEPLOY-PRIVATE.md` | Local-only private server notes; ignored by git |

## Quick Start

```bash
git clone <repo-url> /tmp/Serve
cd /tmp/Serve
sudo INSTALL_TARGET=/opt/Serve SSH_PORT=29222 ./scripts/install-server.sh

cd /opt/Serve
sudo nano .env
docker compose config --quiet
docker compose up -d postgres newapi
```

After NewAPI is reachable, create the NewAPI token, write it to
`NEWAPI_MASTER_KEY`, then start Open WebUI and the tunnel:

```bash
docker compose up -d open-webui cloudflared
docker compose ps
```

See [AUTO-DEPLOY-PUBLIC.md](AUTO-DEPLOY-PUBLIC.md) for the complete deployment,
Cloudflare, backup, optional image site, optional xui, and migration checklist.

## Access Policy

Recommended public hostname split:

| Hostname | Target | Policy |
|---|---|---|
| `chat.*` | `http://open-webui:8080` | Open WebUI login; optional Cloudflare Access |
| `admin.*` | `http://newapi:3000` | Cloudflare Access required |
| `api.*` | `http://newapi:3000` | Bearer token only; no Cloudflare Access |

Do not expose `3000`, `5432`, `8080`, or `7890` directly to the public internet.

## Operations

```bash
docker compose ps
docker compose logs -f --tail=200 newapi
STACK_DIR=/opt/Serve ./backup/pg_dump.sh
curl -x http://172.18.0.1:7890 -I --max-time 10 http://www.gstatic.com/generate_204
```

For a second server, start from `AUTO-DEPLOY-PUBLIC.md` and copy only sanitized
configuration plus verified backups. Do not copy private live-server artifacts into the
public repo.
