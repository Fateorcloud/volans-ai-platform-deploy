# Open Source Release Checklist

Use this checklist before publishing or updating the public repository.

## Required Files

- `README.md` and `README.en.md` describe the LobeHub local-only deployment.
- `.env.example` contains placeholders only.
- `.gitignore` excludes generated credentials, databases, backups, and logs.
- `LICENSE` is present.
- `SECURITY.md` documents secret handling and local port boundaries.
- `scripts/80_security_scan.sh` passes.

## Privacy Review

Confirm the repository does not contain:

- Real domains that should remain private.
- Real VPS IP addresses.
- Real provider API keys.
- Real `KEY_VAULTS_SECRET`, `AUTH_SECRET`, PostgreSQL passwords, RustFS keys,
  or SearXNG secrets.
- SSH private keys, public keys, or known-hosts files.
- `postgres_data/`, `redis_data/`, `rustfs_data/`, or backup archives.
- Private deployment notes.

## Suggested Release Commands

```bash
bash scripts/80_security_scan.sh
git status --short
git add .
git commit -m "refactor: simplify deployment to lobehub"
git push
```

Recommended repository description:

```text
Local-first Ubuntu deployment toolkit for self-hosted LobeHub with PostgreSQL,
Redis, RustFS, and SearXNG.
```
