# Volans LobeHub Self-Deploy Kit

English | [Chinese](README.md)

This is a small self-hosting toolkit for LobeHub. The default stack is now only
`LobeHub + PostgreSQL/PGVector + Redis + RustFS/S3 + SearXNG`, designed for a
local-only first test phase.

The previous NewAPI, Open WebUI, GPT Image Playground, and Caddy image site have
been removed from the current project. The old deployable chain is backed up in
the GitHub branch `codex/legacy-ai-stack-backup`. xui and the NAT egress proxy
are retained as explicit optional network components, but they are not part of
the LobeHub AI platform core stack.

## Architecture

```text
Browser over SSH tunnel
  -> 127.0.0.1:3210  LobeHub
  -> 127.0.0.1:9000  RustFS S3 API, for uploads

LobeHub
  -> 127.0.0.1:15432 PostgreSQL / PGVector
  -> 127.0.0.1:16379 Redis
  -> 127.0.0.1:9000  RustFS
  -> 127.0.0.1:18080 SearXNG
  -> provider APIs configured in .env

Optional network components
  -> xui side stack, installed only by deploy.sh xui
  -> NAT egress proxy, installed only by deploy.sh nat-proxy
```

LobeHub uses host networking so `S3_ENDPOINT=http://127.0.0.1:9000` works for
both the LobeHub server and a browser connected through an SSH tunnel. The data
services bind to `127.0.0.1` only.

## Quick Start

On a fresh Ubuntu 22.04/24.04 VPS:

```bash
git clone https://github.com/<your-name>/volans-ai-platform-deploy.git
cd volans-ai-platform-deploy
cp .env.example .env
nano .env
sudo bash deploy.sh fresh --yes
```

Replace at least:

```text
KEY_VAULTS_SECRET
AUTH_SECRET
POSTGRES_PASSWORD
RUSTFS_ACCESS_KEY
RUSTFS_SECRET_KEY
SEARXNG_SECRET
```

Generate secrets with:

```bash
# KEY_VAULTS_SECRET and AUTH_SECRET
openssl rand -base64 32

# POSTGRES_PASSWORD, RUSTFS_SECRET_KEY, and SEARXNG_SECRET can use hex
openssl rand -hex 32
```

Fill provider keys as needed:

```text
OPENAI_API_KEY
ANTHROPIC_API_KEY
GOOGLE_API_KEY
DEEPSEEK_API_KEY
OPENROUTER_API_KEY
```

## Local Access

From your local machine:

```bash
ssh -L 3210:127.0.0.1:3210 -L 9000:127.0.0.1:9000 <server-alias>
```

Open:

```text
http://127.0.0.1:3210
```

RustFS console is available locally at:

```text
http://127.0.0.1:9001
```

## Operations

```bash
sudo bash deploy.sh verify
sudo bash deploy.sh backup
sudo bash deploy.sh repair --yes
```

Optional network components are explicit:

```bash
sudo bash deploy.sh xui --yes
sudo bash deploy.sh nat-proxy --yes
sudo bash deploy.sh network --yes
```

`fresh` and `repair` do not install xui or NAT proxy components automatically.

Deploy directory:

```text
/opt/lobehub
```

Useful checks:

```bash
cd /opt/lobehub
docker compose ps
docker compose logs -f lobehub
docker compose logs -f lobe-rustfs
```

## Backup And Migration

Manual backup:

```bash
sudo bash deploy.sh backup
```

Default backup files:

```text
/opt/lobehub/backup/postgres_lobechat_YYYY-MM-DD_HHMMSS.sql.gz
/opt/lobehub/backup/rustfs_data_YYYY-MM-DD_HHMMSS.tar.gz
```

For a second server, copy the private `.env`, restore PostgreSQL, restore RustFS
data, then run the verification command. Never commit these private artifacts.

## Public Exposure

This template does not publish a public hostname in the first phase. Before
adding `chat.example.com`, configure LobeHub authentication, reverse proxy
`127.0.0.1:3210`, provide a browser-accessible S3 endpoint, and update `APP_URL`
plus `S3_ENDPOINT`.

## More Docs

- [Deployment flow](docs/deployment.md)
- [Operations](docs/operations.md)
- [Optional xui/NAT network components](docs/network-components.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Migration and trim](docs/migration-and-trim.md)
- [Open-source release checklist](docs/open-source-release.md)

## Open Source Safety

```bash
bash deploy.sh security-scan
git status --short
```

Do not commit real `.env`, API keys, server IPs, SSH keys, database directories,
RustFS logs, or backups.
