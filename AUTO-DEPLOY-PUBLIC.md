# LobeHub Public Auto-Deploy Runbook

This is the GitHub-safe deployment runbook. It contains no secrets, no real
tokens, no private domains, and no server-specific backup data.

## Repository Branches

| Branch | Purpose |
|---|---|
| `codex/deploy-template-cleanup` | Current LobeHub deployment template |
| `codex/legacy-ai-stack-backup` | Deployable backup of the old NewAPI + Open WebUI + image site + xui/NAT chain |

Use the current branch for new servers. Use the legacy branch only if you need
to redeploy or inspect the old stack.

## Deployment Shape

Default core stack:

```text
Browser over SSH tunnel
  -> 127.0.0.1:3210  LobeHub
  -> 127.0.0.1:9000  RustFS S3 API

LobeHub
  -> 127.0.0.1:15432 PostgreSQL / PGVector
  -> 127.0.0.1:16379 Redis
  -> 127.0.0.1:9000  RustFS
  -> 127.0.0.1:18080 SearXNG
  -> provider APIs configured in .env
```

The default deployment does not install NewAPI, Open WebUI, GPT Image
Playground, Caddy image site, xui, or NAT proxy.

xui and NAT are retained only as optional network components:

```bash
sudo bash deploy.sh xui --yes
sudo bash deploy.sh nat-proxy --yes
sudo bash deploy.sh network --yes
```

## Fresh Server Bootstrap

Assumptions:

- Ubuntu 22.04/24.04.
- Root shell or passwordless sudo.
- Docker can be installed from Docker CE packages.
- Provider API keys are ready, or model calls can wait until `.env` is filled.

```bash
git clone <your-github-repo-url> /tmp/lobehub-deploy
cd /tmp/lobehub-deploy
cp .env.example .env
nano .env
sudo bash deploy.sh fresh --yes
```

Required values:

```text
KEY_VAULTS_SECRET
AUTH_SECRET
POSTGRES_PASSWORD
RUSTFS_ACCESS_KEY
RUSTFS_SECRET_KEY
SEARXNG_SECRET
```

Generate examples:

```bash
openssl rand -base64 32
openssl rand -hex 32
```

Optional provider values:

```text
OPENAI_API_KEY
ANTHROPIC_API_KEY
GOOGLE_API_KEY
DEEPSEEK_API_KEY
OPENROUTER_API_KEY
```

## Optional xui/NAT

Edit `.env` only if needed:

```env
ENABLE_XUI=true
XUI_ADMIN_USERNAME=CHANGE_ME_XUI_ADMIN
XUI_ADMIN_PASSWORD=CHANGE_ME_XUI_PASSWORD

ENABLE_NAT_PROXY=true
NAT_SSH_HOST=<nat-server-hostname>
NAT_SSH_PORT=22
NAT_SSH_USER=root
NAT_SSH_KEY_PATH=/root/.ssh/nat_ed25519
```

Then run:

```bash
sudo bash deploy.sh network --yes
```

If LobeHub provider calls should use that proxy, set:

```env
HTTP_PROXY=http://127.0.0.1:7890
HTTPS_PROXY=http://127.0.0.1:7890
```

Then recreate LobeHub:

```bash
cd /opt/lobehub
docker compose up -d --force-recreate lobehub
```

## Local Access

From your laptop:

```bash
ssh -L 3210:127.0.0.1:3210 -L 9000:127.0.0.1:9000 <server-alias>
```

Open:

```text
http://127.0.0.1:3210
```

For RustFS console:

```bash
ssh -L 9001:127.0.0.1:9001 <server-alias>
```

Then open:

```text
http://127.0.0.1:9001
```

## Verification

```bash
sudo bash deploy.sh verify
```

Expected:

- LobeHub, PostgreSQL, Redis, RustFS, RustFS init, and SearXNG containers exist.
- `3210`, `9000`, `9001`, `15432`, `16379`, and `18080` are not public listeners.
- `http://127.0.0.1:3210` returns an HTTP response.
- New conversations persist across `docker compose restart`.

## Backups

Manual backup:

```bash
sudo bash deploy.sh backup
```

Default backup outputs:

```text
/opt/lobehub/backup/postgres_lobechat_YYYY-MM-DD_HHMMSS.sql.gz
/opt/lobehub/backup/rustfs_data_YYYY-MM-DD_HHMMSS.tar.gz
```

Do a restore drill before treating the backup chain as reliable.

## Do Not Commit

- `.env` or `.env.*`
- provider API keys or LobeHub secrets
- SSH keys, NAT hostnames, xui credentials
- `postgres_data/`, `redis_data/`, `rustfs_data/`, `rustfs_logs/`
- backup archives
- private deployment notes
