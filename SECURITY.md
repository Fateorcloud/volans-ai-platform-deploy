# Security Policy

This repository is designed to be public. Do not commit production secrets,
server-specific credentials, database dumps, user lists, private keys, or backup
archives.

## Never Commit

- `.env` or any filled environment file
- Provider API keys, including OpenAI, Anthropic, Google, DeepSeek, OpenRouter,
  Qwen, Moonshot, Mistral, Groq, Perplexity, and xAI
- LobeHub secrets such as `KEY_VAULTS_SECRET` and `AUTH_SECRET`
- PostgreSQL passwords, RustFS access keys, or SearXNG secrets
- SSH private keys, known-hosts files, or server-specific notes
- `postgres_data/`, `redis_data/`, `rustfs_data/`, or backup archives

## Before Publishing

Run:

```bash
bash scripts/80_security_scan.sh
```

The scan is intentionally conservative. If it reports a false positive, prefer
rewriting the file to use placeholders instead of adding broad allow rules.

## Runtime Boundaries

The first deployment phase is local-only. These ports should bind to
`127.0.0.1`, not public interfaces:

```text
3210  LobeHub
9000  RustFS S3 API
9001  RustFS console
15432 PostgreSQL
16379 Redis
18080 SearXNG
```

Only your SSH port should be public during the local test phase. Publish LobeHub
through a reverse proxy or Cloudflare Tunnel only after authentication and S3
public endpoint behavior are deliberately configured.
