# Optional xui/NAT Network Components

The LobeHub AI platform does not require xui or a NAT egress proxy. These files
are retained only for users who still need an independent network layer.

## Boundary

| Component | Command | Role |
|---|---|---|
| xui | `sudo bash deploy.sh xui --yes` | Optional Reality/Xray side stack |
| NAT proxy | `sudo bash deploy.sh nat-proxy --yes` | Optional SSH SOCKS tunnel plus local HTTP proxy |
| Combined setup | `sudo bash deploy.sh network --yes` | Runs xui and NAT setup in sequence |

`sudo bash deploy.sh fresh --yes` installs only LobeHub, PostgreSQL, Redis,
RustFS, and SearXNG. It does not install xui, NAT, NewAPI, Open WebUI, or any
image site.

## Enable

Edit `.env`:

```env
ENABLE_XUI=true
XUI_ADMIN_USERNAME=CHANGE_ME_XUI_ADMIN
XUI_ADMIN_PASSWORD=CHANGE_ME_XUI_PASSWORD
XUI_REALITY_PORT=31444

ENABLE_NAT_PROXY=true
NAT_SSH_HOST=<nat-server-hostname>
NAT_SSH_PORT=22
NAT_SSH_USER=root
NAT_SSH_KEY_PATH=/root/.ssh/nat_ed25519
```

Run:

```bash
sudo bash deploy.sh network --yes
```

If the NAT proxy should be used by LobeHub provider calls, set:

```env
HTTP_PROXY=http://127.0.0.1:7890
HTTPS_PROXY=http://127.0.0.1:7890
NO_PROXY=localhost,127.0.0.1,.local
```

Then recreate LobeHub:

```bash
cd /opt/lobehub
docker compose up -d --force-recreate lobehub
```

## Security Notes

- Do not commit `NAT_SSH_HOST` if it is private.
- Do not commit SSH keys or known-hosts files.
- Do not expose the xui panel publicly without a deliberate access policy.
- The NAT HTTP proxy listens on `127.0.0.1:7890` for LobeHub provider calls.
