# Volans AI Platform One-Shot Deployment Toolkit

English | [Chinese](README.md)

Volans AI Platform Deploy is a self-hosting deployment toolkit for small teams and personal AI labs. It packages Open WebUI, NewAPI, Cloudflare Tunnel, GPT Image Playground, 3xui, Caddy, PostgreSQL, and a NAT VPS egress chain into an auditable Docker Compose based deployment.

The goal is simple: start from a fresh Ubuntu 22.04 VPS, fill `.env`, run one deployment command, and reproduce the core platform. External control-plane tasks such as Cloudflare Access policies, NewAPI model channels, and 3xui Reality inbound settings are documented as explicit post-deployment steps.

## What This Project Solves

Many self-hosted AI guides stop at "the WebUI is running". A real small-circle deployment needs more:

- Users need a friendly chat entrypoint without seeing upstream API keys.
- NewAPI admin pages must not be exposed directly to the public internet; the OpenAI-compatible API hostname must remain directly callable with Bearer tokens.
- Open WebUI signup should be open but default to pending approval.
- Upstream AI APIs should be able to exit through a NAT VPS while normal web and proxy traffic exits through the main VPS.
- The image generation page may use a small shared token, but the entrypoint still needs Basic Auth and fail2ban protection.
- The 3xui panel should be managed through Cloudflare Access while the proxy node itself uses direct VLESS Reality.

This repository turns those constraints into a default-safe deployment skeleton.

## Features

- **One-shot core deployment**: PostgreSQL, NewAPI, Open WebUI, Cloudflare Tunnel, GPT Image Playground, and Caddy.
- **Small-circle user policy**: Open WebUI signup enabled, new users default to `pending`, admins approve users later.
- **Protected admin gateways**: the NewAPI admin hostname and 3xui panel are protected by Cloudflare Access; the API hostname is not.
- **Split egress**: NewAPI upstream requests and 3xui AI-domain traffic can exit through a NAT VPS; normal traffic exits through the main VPS.
- **Protected image site**: `image.example.com` uses Caddy HTTPS + Basic Auth, with fail2ban templates included.
- **3xui Reality node**: panel is not publicly exposed, the Reality node uses a dedicated public port, and a Mihomo example config is included.
- **Operations scripts**: deploy, repair, backup, verify, NAT proxy repair, and public-release security scan.
- **Open-source safe defaults**: examples use placeholders, and `.gitignore` plus `SECURITY.md` document common leak risks.

## Who It Is For

Good fit:

- You have a main VPS and a NAT VPS that can be used as AI egress.
- You want to self-host Open WebUI + NewAPI for a small group.
- You want Cloudflare Tunnel/Access to reduce exposed admin surfaces.
- You want a 3xui node where normal traffic exits the main VPS and AI traffic exits the NAT VPS.

Not a good fit:

- You do not want to touch Linux, Docker, Cloudflare, or the 3xui panel.
- You need large-scale commercial billing, tenant automation, or support workflows.
- You expect every NewAPI channel and every 3xui Reality parameter to be configured automatically by scripts.

## Components

| Component | Purpose | Default exposure |
| --- | --- | --- |
| Open WebUI | User chat entrypoint, signup, pending approval | Cloudflare Tunnel |
| NewAPI | Upstream channels, tokens, quotas, model groups | Cloudflare Tunnel + Access |
| PostgreSQL | Database for NewAPI and Open WebUI | Docker internal network |
| Cloudflared | Publishes chat/api/proxy panel hostnames | Outbound Tunnel |
| GPT Image Playground | Small-circle image generation page | Behind Caddy |
| Caddy | HTTPS + Basic Auth for `image.example.com` | 80/443 |
| 3xui | Reality node and Xray routing management | Panel via Tunnel, node via public high port |
| Privoxy + SSH SOCKS | NAT VPS egress chain | Docker bridge only |
| fail2ban | Blocks repeated Basic Auth failures | Host-level service |

## Architecture

```text
chat.example.com  -> Cloudflare Tunnel -> open-webui:8080
admin.example.com -> Cloudflare Access -> Cloudflare Tunnel -> newapi:3000
api.example.com   -> Bearer token only -> Cloudflare Tunnel -> newapi:3000
image.example.com -> DNS only -> Caddy 80/443 -> gpt-image-playground:80
proxy.example.com -> Cloudflare Access -> Cloudflare Tunnel -> xui-3xui:12053

Open WebUI -> Docker internal http://newapi:3000/v1
NewAPI upstream AI requests -> 172.18.0.1:7890 -> Privoxy -> SSH SOCKS -> NAT VPS
3xui AI-routed requests -> 172.19.0.1:7890 -> Privoxy -> SSH SOCKS -> NAT VPS
3xui normal requests -> direct -> main VPS
```

Expected public ports:

```text
SSH_PORT/tcp
80/tcp
443/tcp
XUI_REALITY_PORT/tcp
```

Must not be public:

```text
3000 NewAPI
8080 Open WebUI
12053 3xui panel
5432 PostgreSQL
7890 Privoxy
10808 SSH SOCKS
```

## Quick Start

On a fresh Ubuntu 22.04 VPS:

```bash
git clone https://github.com/<your-name>/volans-ai-platform-deploy.git
cd volans-ai-platform-deploy
cp .env.example .env
nano .env
sudo bash deploy.sh fresh --yes
```

Read-only verification:

```bash
sudo bash deploy.sh verify
# or
sudo bash verify.sh
```

Repair only the NAT egress proxy chain:

```bash
sudo bash deploy.sh proxy --yes
```

Run a PostgreSQL backup:

```bash
sudo bash deploy.sh backup
# or
sudo bash backup.sh
```

## Required `.env` Values

At minimum, replace:

```text
DB_PASS
NEWAPI_MASTER_KEY
CF_TUNNEL_TOKEN
WEBUI_SECRET_KEY
NAT_SSH_HOST
NAT_SSH_PORT
NAT_SSH_USER
NAT_SSH_KEY_PATH
```

Generate an Open WebUI secret:

```bash
openssl rand -hex 32
```

`NEWAPI_MASTER_KEY` must be an active OpenAI-compatible token created in the NewAPI dashboard, usually starting with `sk-`. It is not the NewAPI admin password and should never be committed.

## Manual Cloudflare Setup

The scripts deploy server-side services only. Configure Cloudflare manually:

```text
Tunnel Public Hostnames:
chat.example.com  -> HTTP open-webui:8080
admin.example.com -> HTTP newapi:3000
api.example.com   -> HTTP newapi:3000
proxy.example.com -> HTTP xui-3xui:12053

Access:
chat.example.com  no Access policy
admin.example.com Access policy, admin email only
api.example.com   no Access policy; keep Authorization: Bearer calls working
proxy.example.com Access policy, admin email only

DNS:
image.example.com -> <HK_VPS_IP>, DNS only
```

`image.example.com` does not use Tunnel in this design. It is served by Caddy on the origin with HTTPS + Basic Auth.

## 3xui Split Egress

Reproduced strategy:

```text
Panel: proxy.example.com through Cloudflare Tunnel + Access
Node: <HK_VPS_IP>:<REALITY_PORT>, VLESS + TCP + Reality
Normal sites: direct, main VPS egress
AI domains: nat-ai, through 172.19.0.1:7890 to NAT VPS
```

In the 3xui panel, create a VLESS TCP Reality inbound using `XUI_REALITY_PORT`, enable sniffing, and create an outbound:

```json
{
  "tag": "nat-ai",
  "protocol": "http",
  "settings": {
    "servers": [
      {
        "address": "172.19.0.1",
        "port": 7890
      }
    ]
  }
}
```

Then add routing rules for AI domains to `nat-ai`. For client configuration, use:

```text
templates/mihomo-reality.example.yaml
```

Do not commit generated client configs with real UUIDs, Reality keys, or real server IPs.

## Verification

Service status:

```bash
cd /opt/Serve && docker compose ps
cd /opt/Serve/xui && docker compose ps
systemctl is-active nat-socks privoxy ai-proxy-firewall fail2ban
```

Port boundaries:

```bash
ss -lntup | grep -E ':(80|443|29222|<REALITY_PORT>|7890)'
ufw status verbose
iptables -S INPUT | grep 7890
```

Egress checks:

```bash
# Host direct egress: main VPS
curl -4s https://api.ipify.org

# AI platform Docker network through NAT VPS
docker run --rm --network ai-platform_ai-net curlimages/curl:8.10.1 \
  -x http://172.18.0.1:7890 -4sS https://api.ipify.org

# 3xui Docker network through NAT VPS
docker run --rm --network xui_default curlimages/curl:8.10.1 \
  -x http://172.19.0.1:7890 -4sS https://api.ipify.org
```

## More Docs

- [Deployment flow](docs/deployment.md)
- [Operations](docs/operations.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Migration and trim runbook](docs/migration-and-trim.md)
- [Open-source release notes](docs/open-source-release.md)

## Open Source Safety

Before publishing:

```bash
bash deploy.sh security-scan
# or
bash scripts/80_security_scan.sh
```

Read:

```text
docs/open-source-release.md
SECURITY.md
```

Never commit real `.env`, database directories, backup archives, plaintext passwords, Cloudflare tokens, NewAPI/OpenAI keys, SSH private keys, 3xui databases, Reality private keys, or live client configs.

## Current Limits

- NewAPI channels, quotas, groups, and model mappings are configured in the NewAPI dashboard.
- `NEWAPI_MASTER_KEY` must be a valid NewAPI token; otherwise Open WebUI users will not see models.
- The first Open WebUI admin account should still be created through the WebUI flow.
- 3xui Reality inbound, client UUIDs, Reality keys, `nat-ai` outbound, and routing rules are still best configured in the 3xui panel.
- Cloudflare Access policies must be configured in the Cloudflare dashboard.

## License

MIT. See [LICENSE](LICENSE).
