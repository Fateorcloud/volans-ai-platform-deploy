# Volans AI Platform 一站式部署工具

[English](README.en.md) | 简体中文

Volans AI Platform Deploy 是一个面向小团队和个人自托管的 AI 平台部署工具。它把 Open WebUI、NewAPI、Cloudflare Tunnel、GPT Image Playground、3xui、Caddy、PostgreSQL 以及 NAT VPS 出站代理链整理成一套可审计、可复现的 Docker Compose 部署方案。

目标是：拿到一台新的 Ubuntu 22.04 VPS 后，按 README 填 `.env`、执行一条部署命令，就能复现核心平台；Cloudflare Access、3xui 入站与 NewAPI 模型渠道这类必须在外部控制台或 Web 面板完成的部分，会明确列成部署后步骤。

## 这个项目解决什么

很多 AI 自托管方案只解决“把 WebUI 跑起来”，但生产使用还会遇到几个实际问题：

- 普通用户需要一个易用的聊天入口，但不能直接接触上游 API Key。
- NewAPI 管理后台需要强身份保护，不能裸露在公网；OpenAI 兼容 API 域名要保留 Bearer token 直连能力。
- Open WebUI 注册需要 pending 审核，适合小圈子开放注册。
- 上游 AI API 希望走 NAT VPS 出口，普通 Web 和 VPN 流量仍走主 VPS 出口。
- 图片生成页面希望内置小额 token，但入口要有 Basic Auth 和 fail2ban 防护。
- 3xui 面板要通过 Cloudflare Access 管理，代理节点本身走 Reality 直连。

本仓库把这些约束收敛成一个默认安全的部署骨架。

## 功能特性

- **一键部署主平台**：PostgreSQL、NewAPI、Open WebUI、Cloudflare Tunnel、GPT Image Playground、Caddy。
- **小圈子用户策略**：Open WebUI 开放注册，默认 `pending`，管理员审核后可用。
- **管理员网关保护**：NewAPI 管理域与 3xui 面板通过 Cloudflare Access 保护，API 域名不挂 Access。
- **双出口分流**：NewAPI 上游与 3xui AI 域名可走 NAT VPS，普通访问走主 VPS。
- **图片站保护**：`image.example.com` 使用 Caddy HTTPS + Basic Auth，并提供 fail2ban 模板。
- **3xui Reality 节点**：面板不暴露公网，节点端口独立开放，支持 Mihomo 客户端模板。
- **运维脚本**：部署、修复、备份、验证、NAT 代理修复、开源前安全扫描。
- **隐私友好开源**：示例配置使用占位符，`.gitignore` 和 `SECURITY.md` 防止常见泄漏。

## 适合谁

适合：

- 有一台主 VPS 和一台可作为 AI 出口的 NAT VPS。
- 希望自托管 Open WebUI + NewAPI 给小团队使用。
- 希望通过 Cloudflare Tunnel/Access 减少公网管理面暴露。
- 希望用 3xui 提供一个“普通流量主 VPS、AI 流量 NAT VPS”的分流节点。

不适合：

- 完全不想接触 Linux、Docker、Cloudflare 控制台或 3xui 面板。
- 需要大规模商业化用户计费、自动工单、复杂租户权限。
- 需要脚本自动配置所有 NewAPI 渠道和 3xui Reality 参数。

## 组件一览

| 组件 | 作用 | 默认暴露方式 |
| --- | --- | --- |
| Open WebUI | 用户聊天入口、注册与 pending 审核 | Cloudflare Tunnel |
| NewAPI | 上游模型渠道、token、额度、分组管理 | Cloudflare Tunnel + Access |
| PostgreSQL | NewAPI/Open WebUI 数据库 | Docker 内网 |
| Cloudflared | 发布 chat/api/proxy 面板域名 | 出站 Tunnel |
| GPT Image Playground | 小圈子图片生成页面 | Caddy 反代 |
| Caddy | `image.example.com` HTTPS + Basic Auth | 80/443 |
| 3xui | Reality 节点和 Xray 分流管理 | 面板走 Tunnel，节点开放高位端口 |
| Privoxy + SSH SOCKS | NAT VPS 出口代理链 | 仅 Docker 网桥可访问 |
| fail2ban | Basic Auth 暴力尝试封禁 | 服务器本机 |

## 用户与模型权限策略

```text
管理员：可以维护外部连接、NewAPI 渠道和模型列表
普通用户：可以使用管理员配置好的所有模型
普通用户：不能自填外部 API 地址
普通用户：不能自填个人 API Key
普通用户：不能创建 Open WebUI API Key
```

对应 Open WebUI 配置：

```env
OPENWEBUI_BYPASS_MODEL_ACCESS_CONTROL=true
OPENWEBUI_ENABLE_DIRECT_CONNECTIONS=false
OPENWEBUI_ENABLE_API_KEYS=false
OPENWEBUI_USER_PERMISSIONS_FEATURES_API_KEYS=false
OPENWEBUI_ENABLE_WEB_SEARCH=true
OPENWEBUI_WEB_SEARCH_ENGINE=brave
OPENWEBUI_BRAVE_SEARCH_API_KEY=CHANGE_ME_BRAVE_SEARCH_API_KEY
OPENWEBUI_BYPASS_WEB_SEARCH_WEB_LOADER=false
OPENWEBUI_BYPASS_WEB_SEARCH_EMBEDDING_AND_RETRIEVAL=false
OPENWEBUI_USER_PERMISSIONS_FEATURES_WEB_SEARCH=true
```

注意：`NEWAPI_MASTER_KEY` 不是 NewAPI 后台管理密钥，也不是随便生成的占位字符串。它必须是在 NewAPI 后台创建的、状态为启用的 OpenAI 兼容 token，格式通常是 `sk-...`。Open WebUI 会用它访问 `http://newapi:3000/v1/models` 和发起聊天请求；如果 token 被删除、停用、额度归零或分组没有模型，管理员和普通用户都会看不到模型。

Web Search 默认使用 Brave Search API，新闻和时效检索质量明显强于无 key 的 DDGS/DuckDuckGo。默认保留网页正文抓取和检索，不绕过 loader，也不只依赖搜索摘要。当前模板会在 Open WebUI 容器启动时应用一个很小的 `safe_web` 兼容补丁，修复异步正文抓取里重复传递 `allow_redirects` 导致正文为空的问题。Open WebUI 自身不配置 `HTTP_PROXY/HTTPS_PROXY`，因此搜索默认走 HK VPS 出口；NewAPI 调上游模型仍按 NAT VPS 代理链路走。

不要把 Brave Search API Key 提交到 Git。部署时只写入服务器 `.env`：

```bash
cd /opt/Serve
sudo nano .env
```

填入：

```env
OPENWEBUI_WEB_SEARCH_ENGINE=brave
OPENWEBUI_BRAVE_SEARCH_API_KEY=你的 Brave Search API Key
OPENWEBUI_WEB_SEARCH_RESULT_COUNT=5
```

然后重建：

```bash
docker compose config --quiet
docker compose up -d --force-recreate open-webui
```
## 当前架构

```text
chat.example.com  -> Cloudflare Tunnel -> open-webui:8080
admin.example.com -> Cloudflare Access -> Cloudflare Tunnel -> newapi:3000
api.example.com   -> Bearer token only -> Cloudflare Tunnel -> newapi:3000
image.example.com -> DNS only -> Caddy 80/443 -> gpt-image-playground:80
proxy.example.com -> Cloudflare Access -> Cloudflare Tunnel -> xui-3xui:12053

Open WebUI -> Docker 内网 http://newapi:3000/v1
NewAPI 上游 AI 请求 -> 172.18.0.1:7890 -> Privoxy -> SSH SOCKS -> NAT VPS
3xui AI 分流请求 -> 172.19.0.1:7890 -> Privoxy -> SSH SOCKS -> NAT VPS
3xui 普通请求 -> direct -> HK VPS
```

公网端口策略：

```text
29222/tcp  SSH
80/tcp     Caddy image.example.com HTTP/ACME
443/tcp    Caddy image.example.com HTTPS
<REALITY_PORT>/tcp  3xui VLESS Reality 入站
```

不能公网开放：

```text
3000 NewAPI
8080 Open WebUI
12053 3xui 面板
5432 PostgreSQL
7890 Privoxy
```

## 一键部署

在新 VPS 上：

```bash
git clone https://github.com/<your-name>/volans-ai-platform-deploy.git
cd volans-ai-platform-deploy
cp .env.example .env
nano .env
sudo bash deploy.sh fresh --yes
```

如果你不是从 GitHub 拉取，而是手动上传目录：

```bash
cd volans-ai-platform-deploy
cp .env.example .env
nano .env
sudo bash deploy.sh fresh --yes
```

只读验证：

```bash
sudo bash deploy.sh verify
# 或
sudo bash verify.sh
```

只修复 NAT 出口代理：

```bash
sudo bash deploy.sh proxy --yes
```

执行 PostgreSQL 备份：

```bash
sudo bash deploy.sh backup
# 或
sudo bash backup.sh
```

## `.env` 必填项

复制 `.env.example` 后，至少替换：

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

生成 Open WebUI secret：

```bash
openssl rand -hex 32
```

创建 Open WebUI 专用 NewAPI token：

```text
1. 先在 NewAPI 后台配置好渠道、分组和模型。
2. 在 NewAPI 后台创建一个专门给 Open WebUI 使用的 token。
3. 确认 token 状态为启用，额度足够，分组能访问需要给普通用户使用的模型。
4. 将完整 token 填入 .env 的 NEWAPI_MASTER_KEY，通常以 sk- 开头。
5. 不要把真实 token 提交到 Git。
```

部署后可以在服务器内部验证 token 是否有效，命令只输出模型数量，不应打印 token：

```bash
cd /opt/Serve
docker exec -i open-webui python - <<'PY'
import asyncio, aiohttp, json
from open_webui.config import OPENAI_API_BASE_URLS, OPENAI_API_KEYS

async def main():
    url = OPENAI_API_BASE_URLS.value[0].rstrip("/") + "/models"
    key = OPENAI_API_KEYS.value[0]
    async with aiohttp.ClientSession(timeout=aiohttp.ClientTimeout(total=20), trust_env=True) as session:
        async with session.get(url, headers={"Authorization": "Bearer " + key}) as response:
            data = json.loads(await response.text())
            items = data.get("data", []) if isinstance(data, dict) else []
            print("status=", response.status, "model_count=", len(items))
            print("first_ids=", [item.get("id") for item in items[:5]])

asyncio.run(main())
PY
```

如果启用 `image.example.com` 内置小额共享 key，还需要填写：

```text
IMAGE_SHARED_API_KEY
IMAGE_BASIC_AUTH_HASH
```

Caddy Basic Auth 哈希生成方式：

```bash
docker run --rm caddy:2-alpine caddy hash-password --plaintext '你的密码'
```

把输出填入 `.env`，不要把明文密码提交到 Git。bcrypt 哈希里包含 `$`，建议在 `.env` 中用单引号包住：

```env
IMAGE_BASIC_AUTH_HASH='$2a$14$示例哈希内容'
```

也可以把每个 `$` 写成 `$$`，避免 Docker Compose 把它当变量插值。

## Cloudflare 手动配置

脚本只部署容器和服务器侧配置，不替你操作 Cloudflare 控制台。部署前后需要在 Cloudflare 配置：

```text
Tunnel Public Hostnames:
chat.example.com  -> HTTP open-webui:8080
admin.example.com -> HTTP newapi:3000
api.example.com   -> HTTP newapi:3000
proxy.example.com -> HTTP xui-3xui:12053

Access:
chat.example.com  不加 Access
admin.example.com 加 Access，仅管理员邮箱
api.example.com   不加 Access，保留 Authorization: Bearer 调用
proxy.example.com 加 Access，仅管理员邮箱

DNS:
image.example.com -> <HK_VPS_IP>，DNS only / 灰云
```

`image.example.com` 不走 Tunnel，因为当前方案使用 Caddy 在源站做 HTTPS + Basic Auth。`proxy.example.com` 只作为 3xui 管理面板，不作为 Reality 节点域名。

## 3xui 分流部署

当前复现策略：

```text
面板：proxy.example.com，经 Cloudflare Tunnel + Access
节点：<HK_VPS_IP>:<REALITY_PORT>，VLESS + TCP + Reality
普通网站：direct，HK VPS 出口
AI 域名：nat-ai，走 172.19.0.1:7890 到 NAT VPS
```

3xui 容器部署后，在面板中创建入站：

```text
协议：VLESS
传输：TCP
安全：Reality
端口：<REALITY_PORT>
Sniffing：开启
destOverride：http,tls,quic
routeOnly：开启
```

新增出站 `nat-ai`：

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

路由规则示例：

```json
{
  "type": "field",
  "domain": [
    "domain:openai.com",
    "domain:chatgpt.com",
    "domain:oaiusercontent.com",
    "domain:anthropic.com",
    "domain:claude.ai",
    "domain:gemini.google.com",
    "domain:generativelanguage.googleapis.com",
    "domain:aistudio.google.com",
    "domain:perplexity.ai",
    "domain:x.ai",
    "domain:grok.com",
    "domain:api.x.ai"
  ],
  "outboundTag": "nat-ai"
}
```

测试时可临时加入：

```text
domain:api.ipify.org
```

客户端访问 `https://api.ipify.org` 应返回 NAT VPS IP。测试后删除该测试域名，普通访问应返回 HK VPS IP。

Mihomo/Clash Meta 客户端配置模板见：

```text
templates/mihomo-reality.example.yaml
```

模板只保留占位符。不要把真实客户端 UUID、Reality key、真实 VPS IP 或订阅配置提交到 Git。

## 验证命令

服务状态：

```bash
cd /opt/Serve && docker compose ps
cd /opt/Serve/xui && docker compose ps
systemctl is-active nat-socks privoxy ai-proxy-firewall fail2ban
```

端口与安全边界：

```bash
ss -lntup | grep -E ':(80|443|29222|<REALITY_PORT>|7890)'
ufw status verbose
iptables -S INPUT | grep 7890
```

出口验证：

```bash
# 宿主机直连，应为 HK VPS
curl -4s https://api.ipify.org

# AI 平台 Docker 网络经 NAT，应为 NAT VPS
docker run --rm --network ai-platform_ai-net curlimages/curl:8.10.1 \
  -x http://172.18.0.1:7890 -4sS https://api.ipify.org

# 3xui Docker 网络直连，应为 HK VPS
docker run --rm --network xui_default curlimages/curl:8.10.1 \
  -4sS https://api.ipify.org

# 3xui Docker 网络经 NAT，应为 NAT VPS
docker run --rm --network xui_default curlimages/curl:8.10.1 \
  -x http://172.19.0.1:7890 -4sS https://api.ipify.org
```

当前生产参考值：

```text
HK VPS direct = <HK_VPS_IP>
NAT VPS proxy = <NAT_VPS_EGRESS_IP>
```

## 自由替换 NAT VPS

NAT VPS 只承担 AI 高风控出口，不承载 Web 面板。替换 NAT VPS 时，主 VPS 上通常只需要改 `.env` 里的 SSH 目标，然后重启 NAT 代理链。

### 1. 准备新 NAT VPS

在主 VPS 上准备一把连接 NAT VPS 的专用密钥：

```bash
ssh-keygen -t ed25519 -f /root/.ssh/nat_ed25519 -C nat-egress
ssh-copy-id -i /root/.ssh/nat_ed25519.pub -p <NAT_SSH_PORT> <NAT_SSH_USER>@<NAT_SSH_HOST>
```

测试主 VPS 能否免密登录 NAT VPS：

```bash
ssh -i /root/.ssh/nat_ed25519 -p <NAT_SSH_PORT> <NAT_SSH_USER>@<NAT_SSH_HOST> 'curl -4s https://api.ipify.org'
```

返回值应为新 NAT VPS 的出口 IP：

```text
<NAT_VPS_EGRESS_IP>
```

### 2. 修改需要变更的文件

如果是在部署项目中重新部署，修改项目根目录：

```text
.env
```

如果是在已部署服务器上直接替换 NAT VPS，修改：

```text
/opt/Serve/.env
/opt/Serve/xui/.env
```

需要修改的变量：

```env
NAT_SSH_HOST=<NAT_SSH_HOST>
NAT_SSH_PORT=<NAT_SSH_PORT>
NAT_SSH_USER=<NAT_SSH_USER>
NAT_SSH_KEY_PATH=/root/.ssh/nat_ed25519
NAT_SOCKS_LISTEN=127.0.0.1:10808
PRIVOXY_AI_LISTEN=172.18.0.1:7890
PRIVOXY_XUI_LISTEN=172.19.0.1:7890
```

通常不需要改：

```text
NewAPI 的 HTTP_PROXY / HTTPS_PROXY
3xui 的 nat-ai 出站
Privoxy 的 172.18.0.1:7890 / 172.19.0.1:7890
Cloudflare Tunnel / Access
```

原因是 NewAPI 和 3xui 都只连接主 VPS 本机的 Privoxy；真正决定 NAT 出口的是 `nat-socks.service` 里的 SSH 目标。

### 3. 重新渲染并重启 NAT 代理链

在部署项目目录执行：

```bash
sudo bash deploy.sh proxy --yes
```

如果是手动维护，也可以执行：

```bash
systemctl daemon-reload
systemctl restart nat-socks
systemctl restart privoxy
systemctl restart ai-proxy-firewall
```

### 4. 验证新 NAT 出口

```bash
# 宿主机直连，应为 HK VPS 出口
curl -4s https://api.ipify.org

# 主 VPS 经 Privoxy，应为 NAT VPS 出口
curl -x http://172.18.0.1:7890 -4s https://api.ipify.org

# NewAPI 所在 Docker 网络经 NAT，应为 NAT VPS 出口
docker run --rm --network ai-platform_ai-net curlimages/curl:8.10.1 \
  -x http://172.18.0.1:7890 -4sS https://api.ipify.org

# 3xui 所在 Docker 网络经 NAT，应为 NAT VPS 出口
docker run --rm --network xui_default curlimages/curl:8.10.1 \
  -x http://172.19.0.1:7890 -4sS https://api.ipify.org
```

预期：

```text
直连 = <HK_VPS_IP>
经 172.18.0.1:7890 = <NAT_VPS_EGRESS_IP>
经 172.19.0.1:7890 = <NAT_VPS_EGRESS_IP>
```

### 5. 常见排查

如果 `nat-socks` 起不来：

```bash
journalctl -u nat-socks -n 100 --no-pager
```

如果 Docker 容器访问 `7890` 超时：

```bash
ss -lntup | grep ':7890'
iptables -S INPUT | grep 7890
systemctl restart ai-proxy-firewall
```

正常只能看到：

```text
172.18.0.1:7890
172.19.0.1:7890
```

不能出现：

```text
0.0.0.0:7890
[::]:7890
```

## 常用维护命令

主平台：

```bash
cd /opt/Serve
docker compose ps
docker compose config --quiet
docker compose up -d
docker compose logs -f newapi
docker compose logs -f open-webui
docker compose logs -f cloudflared
docker compose logs -f caddy-image
```

3xui：

```bash
cd /opt/Serve/xui
docker compose ps
docker compose config --quiet
docker compose up -d --force-recreate xui
docker compose logs -f xui
docker port xui-3xui
```

NAT 代理链：

```bash
systemctl status nat-socks --no-pager
systemctl status privoxy --no-pager
systemctl status ai-proxy-firewall --no-pager
systemctl restart nat-socks
systemctl restart privoxy
systemctl restart ai-proxy-firewall
```

## 更多文档

- [部署流程](docs/deployment.md)
- [运维手册](docs/operations.md)
- [已知问题处理](docs/troubleshooting.md)
- [迁移与裁剪 Runbook](docs/migration-and-trim.md)
- [开源发布记录](docs/open-source-release.md)

## 开源前检查

```bash
git status --short
bash deploy.sh security-scan
# 或
bash scripts/80_security_scan.sh
```

发布前建议阅读：

```text
docs/open-source-release.md
SECURITY.md
```

允许 `.env.example` 出现占位变量名，但不得提交真实 `.env`、数据库、备份包、明文账号密码、真实 Cloudflare token、OpenAI/NewAPI key、SSH 私钥、3xui 数据库、真实 Reality 客户端配置。

本仓库默认使用 MIT License。如需换成 GPL/Apache/私有许可证，发布前替换 `LICENSE`。

## 当前限制

- NewAPI 模型渠道、额度、分组需要在 NewAPI 后台配置。
- `NEWAPI_MASTER_KEY` 必须使用 NewAPI 后台的有效 token；若 `/models` 返回 `Invalid token`，Open WebUI 中所有用户都会看不到模型。
- Open WebUI 第一个管理员账号仍建议通过 WebUI 首次登录流程创建。
- 3xui Reality 入站、客户端 UUID、Reality key、`nat-ai` 出站和路由目前仍建议在 3xui 面板中配置并保存。
- Cloudflare Access 策略需要在 Cloudflare 控制台配置。
