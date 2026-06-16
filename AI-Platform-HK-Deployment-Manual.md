# AI Platform 香港服务器自部署方案手册

> 公开版说明：本文档已脱敏，真实服务器 IP、真实域名、本地路径和凭证不在公开版中保存。
> 新服务器自动部署请优先执行 `AUTO-DEPLOY-PUBLIC.md`；本文档保留架构背景、决策记录和排障经验。
> 私有服务器状态、迁移偏差和裁剪前检查记录在本机 `AUTO-DEPLOY-PRIVATE.md`，该文件不提交 GitHub。

## 1. 项目概览

**目标**：在香港 VPS 上自部署一套 AI Platform，使用 Open WebUI 作为用户聊天入口，NewAPI 作为模型聚合网关，PostgreSQL 存储业务数据，Cloudflare Tunnel 暴露公网域名，宿主机 Mihomo/Clash 提供出站代理能力。

**部署环境**：

- `[已确认]` 服务器：香港 VPS，公网 IP `<server-public-ip>`
- `[已确认]` 系统：Ubuntu 22.04.3 LTS
- `[已确认]` 部署目录：`/opt/Serve`
- `[已确认]` Docker：`29.4.1`
- `[已确认]` Docker Compose：`v5.1.3`
- `[已确认]` 域名：`example.com`

```mermaid
flowchart LR
    U[用户浏览器 / API Client] --> CF[Cloudflare Edge]
    CF --> T[cloudflared Tunnel]

    T --> CHAT[chat.example.com -> open-webui:8080]
    T --> ADMIN[admin.example.com -> newapi:3000]
    T --> API[api.example.com -> newapi:3000]

    CHAT --> OW[Open WebUI]
    OW --> NA[NewAPI]
    NA --> PG[(PostgreSQL)]
    NA --> PXY[host.docker.internal:7890]
    PXY --> CLASH[Mihomo/Clash on host]
    CLASH --> UP[DeepSeek / CPA / OpenAI-compatible upstreams]
```

最终访问方式：

| 域名 | 指向 | 用途 | 状态 |
|---|---|---|---|
| `chat.example.com` | `open-webui:8080` | 用户聊天入口 | `[已确认可访问]` |
| `admin.example.com` | `newapi:3000` | NewAPI 管理后台 | `[已确认]` Cloudflare Access 邮箱验证码保护 |
| `api.example.com` | `newapi:3000` | OpenAI-compatible API 调用入口 | `[已确认]` 不挂 Access，使用 Bearer Token |

## 2. 最终架构说明

### 2.1 核心调用链

`[已确认]` Open WebUI 不直接调用上游模型，而是调用 NewAPI：

```text
Open WebUI -> http://newapi:3000/v1 -> NewAPI -> 上游模型
```

`[已确认]` NewAPI 连接 PostgreSQL：

```text
postgresql://${DB_USER}:${DB_PASS}@postgres:5432/newapi_db
```

`[已确认]` Open WebUI 连接 PostgreSQL：

```text
postgresql://${DB_USER}:${DB_PASS}@postgres:5432/openwebui_db
```

`[已确认]` NewAPI 出站访问海外模型时走宿主机 Clash：

```text
HTTP_PROXY=http://host.docker.internal:7890
HTTPS_PROXY=http://host.docker.internal:7890
host.docker.internal -> 172.18.0.1
```

`[已确认]` Clash 最终安全监听方式：

```yaml
allow-lan: true
bind-address: "172.18.0.1"
mixed-port: 7890
external-controller: 127.0.0.1:9090
secret: "[REDACTED]"
```

### 2.2 组件关系表

| 组件 | 容器名 | 作用 | 依赖 | 暴露端口 | 是否公网暴露 | 数据持久化 |
|---|---|---|---|---|---|---|
| PostgreSQL | `postgres` | NewAPI / Open WebUI 数据库 | 无 | `5432/tcp` 容器内 | 否 | `./pg_data` |
| NewAPI | `newapi` | 模型聚合、令牌、计费、渠道管理 | PostgreSQL、宿主机代理 | `3000/tcp` 容器内 | 通过 Tunnel 暴露 `admin` / `api` | `./newapi_data` |
| Open WebUI | `open-webui` | 聊天前端、用户入口 | NewAPI、PostgreSQL | `8080/tcp` 容器内 | 通过 Tunnel 暴露 `chat` | `./open-webui_data` |
| Cloudflared | `cloudflare-tunnel` | Cloudflare Tunnel 客户端 | Open WebUI、NewAPI | 无需映射 | 主动连 Cloudflare | 无 |
| Mihomo/Clash | 宿主机 systemd | 出站代理 | Clash 订阅配置 | `172.18.0.1:7890` | 否 | `/etc/clash/config.yaml` |

## 3. 环境参数总表

| 参数 | 示例值/当前值 | 用途 | 是否必填 | 来源/备注 |
|---|---|---|---|---|
| 服务器 IP | `<server-public-ip>` | SSH / 运维入口 | 是 | `[已确认]` |
| 操作系统 | Ubuntu 22.04.3 LTS | 运行 Docker | 是 | `[已确认]` |
| 部署目录 | `/opt/Serve` | Compose 项目目录 | 是 | `[已确认]` |
| Docker | `29.4.1` | 容器运行时 | 是 | `[已确认]` |
| Docker Compose | `v5.1.3` | 编排工具 | 是 | `[已确认]` |
| Compose project | `ai-platform` | Docker 网络名前缀 | 是 | `[已确认]` |
| Docker 网络 | `ai-platform_ai-net` | 服务内网通信 | 是 | `[已确认]` |
| Docker bridge gateway | `172.18.0.1` | 容器访问宿主机 Clash | 是 | `[已确认]` |
| NewAPI 端口 | `3000/tcp` | API / 管理后台 | 是 | 容器内端口 |
| Open WebUI 端口 | `8080/tcp` | Web 前端 | 是 | 容器内端口 |
| PostgreSQL 端口 | `5432/tcp` | 数据库 | 是 | 仅容器内 |
| PostgreSQL 用户 | `ai_admin` | DB 用户 | 是 | `.env.example` |
| PostgreSQL 密码 | `[待填写_POSTGRES_PASSWORD]` | DB 密码 | 是 | `.env` |
| NewAPI DB | `newapi_db` | NewAPI 数据库 | 是 | `init.sql` |
| Open WebUI DB | `openwebui_db` | Open WebUI 数据库 | 是 | `init.sql` |
| NewAPI 调用令牌 | `sk-[REDACTED]` | Open WebUI 调 NewAPI | 是 | NewAPI 令牌页生成 |
| Cloudflare Tunnel Token | `[REDACTED_CLOUDFLARE_TUNNEL_TOKEN]` | cloudflared 连接隧道 | 是 | Cloudflare Zero Trust |
| 主域名 | `example.com` | DNS zone | 是 | `[已确认]` |
| 聊天域名 | `chat.example.com` | Open WebUI | 是 | `[已确认]` |
| 管理域名 | `admin.example.com` | NewAPI 管理后台 | 是 | `[已确认]` Access 保护 |
| API 域名 | `api.example.com` | NewAPI API | 是 | `[已确认]` Bearer token |
| 宿主机代理地址 | `172.18.0.1` | Clash 监听地址 | 是 | `[已确认最终可用]` |
| 宿主机代理端口 | `7890` | Clash mixed-port | 是 | `[已确认最终可用]` |
| `HTTP_PROXY` | `http://host.docker.internal:7890` | 容器 HTTP 出站代理 | 是 | `[已确认]` |
| `HTTPS_PROXY` | `http://host.docker.internal:7890` | 容器 HTTPS 出站代理 | 是 | `[已确认]` |
| `NO_PROXY` | `localhost,127.0.0.1,.local,postgres,newapi,open-webui,playwright,172.16.0.0/12,10.0.0.0/8` | 避免内部流量走代理 | 是 | `[已确认]` |
| `ENABLE_SIGNUP` | `true` | 允许 Open WebUI 注册 | 建议 | 小圈邀请制 |
| `DEFAULT_USER_ROLE` | `pending` | 新用户默认待审核 | 建议 | 管理员批准后分组 |
| `ENABLE_DIRECT_CONNECTIONS` | `false` | 禁止普通用户自填上游 key | 建议 | token 用户不可见 |
| `ENABLE_API_KEYS` | `false` | 禁止普通用户自助创建 Open WebUI API key | 建议 | 后台仍需核对 |
| `USER_PERMISSIONS_FEATURES_API_KEYS` | `false` | 禁止普通用户 API key 功能 | 建议 | 后台仍需核对 |
| `BYPASS_MODEL_ACCESS_CONTROL` | `false` | 启用模型访问控制 | 建议 | 分组模型权限 |
| Clash 控制端口 | `127.0.0.1:9090` | Mihomo REST API | 建议 | 不暴露公网 |
| Clash secret | `[REDACTED]` | 控制 API 密钥 | 建议 | 已设置过，勿泄露 |

## 4. 完整 docker-compose.yaml

> 说明：以下是按最终可用方案整理的版本。重点修正为 `host.docker.internal:172.18.0.1`，避免 `host-gateway` 在本机解析到 `172.17.0.1` 后与自定义网桥不一致。

```yaml
name: ai-platform

networks:
  ai-net:
    driver: bridge

x-logging: &default-logging
  driver: json-file
  options:
    max-size: "50m"
    max-file: "3"

services:
  postgres:
    image: postgres:${POSTGRES_VERSION:-15.8-alpine}
    container_name: postgres
    restart: always
    logging: *default-logging
    environment:
      POSTGRES_USER: ${DB_USER}
      POSTGRES_PASSWORD: ${DB_PASS}
      TZ: Asia/Shanghai
    volumes:
      - ./pg_data:/var/lib/postgresql/data
      - ./init.sql:/docker-entrypoint-initdb.d/init.sql:ro
    expose:
      - "5432"
    networks:
      - ai-net
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${DB_USER}"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 15s
    deploy:
      resources:
        limits:
          memory: 1G

  newapi:
    image: calciumion/new-api:${NEWAPI_VERSION:-latest}
    container_name: newapi
    restart: always
    logging: *default-logging
    extra_hosts:
      - "host.docker.internal:172.18.0.1"
    environment:
      SQL_DSN: postgresql://${DB_USER}:${DB_PASS}@postgres:5432/newapi_db
      TZ: Asia/Shanghai
      GODEBUG: http2client=0
      HTTP_PROXY: http://host.docker.internal:7890
      HTTPS_PROXY: http://host.docker.internal:7890
      NO_PROXY: localhost,127.0.0.1,.local,postgres,newapi,open-webui,playwright,172.16.0.0/12,10.0.0.0/8
    volumes:
      - ./newapi_data:/data
    expose:
      - "3000"
    networks:
      - ai-net
    depends_on:
      postgres:
        condition: service_healthy
    healthcheck:
      test: ["CMD-SHELL", "wget -qO- http://127.0.0.1:3000/api/status >/dev/null || exit 1"]
      interval: 20s
      timeout: 5s
      retries: 5
      start_period: 40s
    deploy:
      resources:
        limits:
          memory: 512M

  open-webui:
    image: ghcr.io/open-webui/open-webui:${OPENWEBUI_VERSION:-main}
    container_name: open-webui
    restart: always
    logging: *default-logging
    extra_hosts:
      - "host.docker.internal:172.18.0.1"
    environment:
      DATABASE_URL: postgresql://${DB_USER}:${DB_PASS}@postgres:5432/openwebui_db
      OPENAI_API_BASE_URL: http://newapi:3000/v1
      OPENAI_API_KEY: ${NEWAPI_MASTER_KEY}
      ENABLE_SIGNUP: ${OPENWEBUI_ENABLE_SIGNUP:-true}
      DEFAULT_USER_ROLE: ${OPENWEBUI_DEFAULT_USER_ROLE:-pending}
      ENABLE_DIRECT_CONNECTIONS: ${OPENWEBUI_ENABLE_DIRECT_CONNECTIONS:-false}
      ENABLE_API_KEYS: ${OPENWEBUI_ENABLE_API_KEYS:-false}
      USER_PERMISSIONS_FEATURES_API_KEYS: ${OPENWEBUI_USER_PERMISSIONS_FEATURES_API_KEYS:-false}
      BYPASS_MODEL_ACCESS_CONTROL: ${OPENWEBUI_BYPASS_MODEL_ACCESS_CONTROL:-false}
      ENABLE_RAG_WEB_SEARCH: "True"
      RAG_WEB_SEARCH_ENGINE: duckduckgo
      RAG_EMBEDDING_ENGINE: openai
      RAG_OPENAI_API_BASE_URL: http://newapi:3000/v1
      RAG_OPENAI_API_KEY: ${NEWAPI_MASTER_KEY}
      RAG_EMBEDDING_MODEL: ${RAG_EMBEDDING_MODEL:-text-embedding-3-large}
      RAG_RERANKING_MODEL: ${RAG_RERANKING_MODEL:-}
      WEB_LOADER_ENGINE: ${WEB_LOADER_ENGINE:-safe_web}
      PLAYWRIGHT_WS_URL: ${PLAYWRIGHT_WS_URL:-}
      PERSONAL_BROWSER_HEADLESS: "true"
      HTTP_PROXY: http://host.docker.internal:7890
      HTTPS_PROXY: http://host.docker.internal:7890
      NO_PROXY: localhost,127.0.0.1,.local,postgres,newapi,open-webui,playwright,172.16.0.0/12,10.0.0.0/8
      TZ: Asia/Shanghai
    volumes:
      - ./open-webui_data:/app/backend/data
    expose:
      - "8080"
    networks:
      - ai-net
    depends_on:
      postgres:
        condition: service_healthy
      newapi:
        condition: service_started
    deploy:
      resources:
        limits:
          memory: 2G

  cloudflared:
    image: cloudflare/cloudflared:${CLOUDFLARED_VERSION:-latest}
    container_name: cloudflare-tunnel
    restart: always
    logging: *default-logging
    command: tunnel --no-autoupdate run
    environment:
      TUNNEL_TOKEN: ${CF_TUNNEL_TOKEN}
    networks:
      - ai-net
    depends_on:
      - open-webui
      - newapi
```

关键配置说明：

- `expose` 只声明容器内端口，不向宿主机公网开放。
- `cloudflared` 和业务容器在同一个 `ai-net` 网络内，Tunnel Service URL 可以直接写 `http://newapi:3000`、`http://open-webui:8080`。
- `GODEBUG=http2client=0` 用于规避 NewAPI 经代理访问部分上游时出现的 Go HTTP/2 协议解析异常。
- `host.docker.internal:172.18.0.1` 是最终修正点。历史上 `host-gateway` 在该服务器解析成 `172.17.0.1`，与 `ai-platform_ai-net` 的网关 `172.18.0.1` 不一致。
- `NEWAPI_MASTER_KEY` 名称沿用模板，实际应填写 NewAPI 令牌页创建的调用 token，格式类似 `sk-[REDACTED]`。

## 5. 目录结构与文件说明

`[已确认]` 当前部署目录为 `/opt/Serve`。

```text
/opt/Serve/
├── docker-compose.yml
├── .env
├── .env.example
├── init.sql
├── README.md
├── CHANGELOG.md
├── OPENWEBUI-SINGLE-TOKEN-SOP.md
├── pg_data/
├── newapi_data/
├── open-webui_data/
├── backup/
│   └── pg_dump.sh
├── systemd/
│   ├── clash.service
│   └── proxy-healthcheck.sh
└── scripts/
    ├── gen-secrets.ps1
    └── install-server.sh
```

文件说明：

| 文件/目录 | 作用 | 状态 |
|---|---|---|
| `docker-compose.yml` | 四容器编排 | 需要采用本文最终版本 |
| `.env` | 真实环境变量，含密码和 token | 不可提交 |
| `.env.example` | 环境变量模板 | 已存在 |
| `init.sql` | 首次初始化 `newapi_db` / `openwebui_db` | 已存在 |
| `OPENWEBUI-SINGLE-TOKEN-SOP.md` | 用户审批、单 token、生图设置 SOP | 建议同步到服务器 |
| `pg_data/` | PostgreSQL 数据目录 | 运行后生成 |
| `newapi_data/` | NewAPI 数据目录 | 运行后生成 |
| `open-webui_data/` | Open WebUI 数据目录 | 运行后生成 |
| `backup/pg_dump.sh` | PG 备份脚本 | 已存在 |
| `systemd/clash.service` | Clash systemd 单元 | 旧描述需更新为非公网监听 |
| `systemd/proxy-healthcheck.sh` | 代理探活脚本 | 建议同步最终代理地址 |

## 6. .env 与 init.sql

`.env` 模板：

```env
DB_USER=ai_admin
DB_PASS=[待填写_POSTGRES_PASSWORD]

NEWAPI_MASTER_KEY=sk-[REDACTED_NEWAPI_TOKEN]

OPENWEBUI_ENABLE_SIGNUP=true
OPENWEBUI_DEFAULT_USER_ROLE=pending
OPENWEBUI_ENABLE_DIRECT_CONNECTIONS=false
OPENWEBUI_ENABLE_API_KEYS=false
OPENWEBUI_USER_PERMISSIONS_FEATURES_API_KEYS=false
OPENWEBUI_BYPASS_MODEL_ACCESS_CONTROL=false

CF_TUNNEL_TOKEN=[REDACTED_CLOUDFLARE_TUNNEL_TOKEN]

RAG_EMBEDDING_MODEL=text-embedding-3-large
RAG_RERANKING_MODEL=

WEB_LOADER_ENGINE=safe_web
PLAYWRIGHT_WS_URL=

POSTGRES_VERSION=15.8-alpine
NEWAPI_VERSION=latest
OPENWEBUI_VERSION=main
CLOUDFLARED_VERSION=latest
```

`init.sql`：

```sql
CREATE DATABASE newapi_db;
CREATE DATABASE openwebui_db;
```

注意：

- `init.sql` 只会在 PostgreSQL 空数据目录首次初始化时执行。
- 如果 `pg_data/` 已经存在，修改 `init.sql` 不会自动重跑。
- 不要随意删除 `pg_data/`，否则会丢数据库。

## 7. 宿主机 Clash / Mihomo 出站代理

### 7.1 最终安全配置

`[已确认]` 最终可用目标：

```yaml
allow-lan: true
bind-address: "172.18.0.1"
mixed-port: 7890
external-controller: 127.0.0.1:9090
secret: "[REDACTED]"
```

含义：

| 配置 | 作用 |
|---|---|
| `allow-lan: true` | 允许 Docker 容器这类非本机回环地址访问代理 |
| `bind-address: "172.18.0.1"` | 只监听 Docker 网桥网关，不监听公网 |
| `mixed-port: 7890` | HTTP/SOCKS 混合代理端口 |
| `external-controller: 127.0.0.1:9090` | Mihomo 控制 API，只允许宿主机本地访问 |
| `secret` | 控制 API 密钥，必须脱敏和轮换 |

### 7.2 防火墙持久化

`[已确认]` 容器访问 `172.18.0.1:7890` 初始会 timeout，加入 iptables 放行后成功。

持久化脚本：

```bash
cat > /usr/local/sbin/clash-docker-firewall.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

BR_IF="$(ip -o addr show | awk '$4 ~ /^172\.18\.0\.1\// {print $2; exit}')"

if [ -z "${BR_IF:-}" ]; then
  echo "ERROR: Docker bridge interface for 172.18.0.1 not found"
  exit 1
fi

iptables -C INPUT -i "$BR_IF" -s 172.18.0.0/16 -d 172.18.0.1 -p tcp --dport 7890 -j ACCEPT 2>/dev/null || \
iptables -I INPUT 1 -i "$BR_IF" -s 172.18.0.0/16 -d 172.18.0.1 -p tcp --dport 7890 -j ACCEPT

echo "OK: allowed Docker bridge $BR_IF -> 172.18.0.1:7890/tcp"
EOF

chmod +x /usr/local/sbin/clash-docker-firewall.sh
```

systemd 单元：

```bash
cat > /etc/systemd/system/clash-docker-firewall.service <<'EOF'
[Unit]
Description=Allow Docker containers to reach host Clash proxy
After=docker.service clash.service
Requires=docker.service

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/clash-docker-firewall.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now clash-docker-firewall.service
```

验证：

```bash
systemctl status clash-docker-firewall --no-pager
iptables -S INPUT | grep 7890
ss -lntup | grep 7890
```

安全预期：

```text
172.18.0.1:7890
```

不能出现：

```text
0.0.0.0:7890
*:7890
```

### 7.3 代理验证命令

宿主机验证：

```bash
curl -x http://172.18.0.1:7890 -I --max-time 10 http://www.gstatic.com/generate_204
```

容器验证：

```bash
docker run --rm --network ai-platform_ai-net \
  curlimages/curl:8.10.1 \
  -x http://172.18.0.1:7890 \
  -I --max-time 10 http://www.gstatic.com/generate_204
```

NewAPI 容器验证：

```bash
docker compose exec newapi sh -c 'getent hosts host.docker.internal; env | grep -i proxy'

docker compose exec newapi sh -c \
'http_proxy=http://host.docker.internal:7890 wget -S -O- -T 10 http://www.gstatic.com/generate_204' 2>&1 | head -30
```

## 8. Cloudflare Tunnel 与域名

### 8.1 Tunnel 路由

`[已确认]` Tunnel 名称：`example-tunnel`

| Public Hostname | Service URL | 说明 |
|---|---|---|
| `chat.example.com` | `http://open-webui:8080` | Open WebUI |
| `admin.example.com` | `http://newapi:3000` | NewAPI 管理后台 |
| `api.example.com` | `http://newapi:3000` | API 调用入口 |

### 8.2 Access 策略

| 域名 | Access 策略 |
|---|---|
| `admin.example.com` | `[已确认]` Cloudflare 邮箱一次性验证码 |
| `api.example.com` | `[已确认]` 不挂 Access，依赖 Bearer Token |
| `chat.example.com` | `[建议]` 可仅用 Open WebUI 登录；如开放给多人，可另加 Access |

### 8.3 API 状态验证

```bash
curl https://api.example.com/api/status
```

`[已确认]` 曾返回 NewAPI 状态 JSON，说明 Tunnel 到 NewAPI 正常。

## 9. NewAPI 渠道配置

### 9.1 DeepSeek

`[已确认]` 最终可用方式：不要使用 NewAPI 原生 DeepSeek 类型，使用 OpenAI-compatible 类型。

| 字段 | 值 |
|---|---|
| 渠道类型 | OpenAI / OpenAI Compatible |
| API 地址 | `https://api.deepseek.com` |
| 密钥 | `[REDACTED_DEEPSEEK_KEY]` |
| 模型 | `deepseek-chat` 等 |
| 分组 | `default` / `svip` 按需 |

历史验证：

```text
deepseek-chat -> 成功
request_path: /v1/chat/completions
```

### 9.2 CPA / CPAMC

`[已确认]` CPA 管理站：

```text
https://qingdeng.custom.tunecoder.com/management.html#/
```

`[已确认]` API Base：

```text
https://qingdeng.custom.tunecoder.com
```

不要填：

```text
https://qingdeng.custom.tunecoder.com/v1
```

NewAPI 渠道：

| 字段 | 值 |
|---|---|
| 渠道类型 | OpenAI / OpenAI Compatible |
| API 地址 | `https://qingdeng.custom.tunecoder.com` |
| 密钥 | `[REDACTED_CPA_API_KEY]` |
| 模型 | `gpt-5.4`, `gpt-5.4-high`, `gpt-5.5`, `gpt-5.5-high` |
| 分组 | `svip` |

`[已确认]` CPA `/v1/models` 曾返回：

```text
gpt-5.5
codex-auto-review
gpt-image-2
gpt-5.2
gpt-5.3-codex
gpt-5.4
gpt-5.4-mini
```

### 9.3 reasoning_effort 别名

`[已确认]` `gpt-5.5-high` 已经传递：

```json
"reasoning_effort": "high"
```

日志证据：

```text
model_name: "gpt-5.5-high"
other.reasoning_effort: "high"
```

普通模型：

```text
model_name: "gpt-5.5"
other 中无 reasoning_effort
```

建议倍率：

| 模型 | 建议倍率 |
|---|---|
| `gpt-5.5` | `2.5` |
| `gpt-5.5-high` | `4.0` |
| `gpt-5.5-xhigh` | `5.0+` |

原因：日志中 high 版本耗时、输出 token 和实际费用均明显更高。

### 9.4 生图模型

`[已确认]` CPA 模型列表包含：

```text
gpt-image-2
```

`[已确认]` Open WebUI 生图已解决：需要在 Open WebUI 图片生成设置里单独配置图片生成 token，不要混用聊天 token。历史错误日志显示，若把 `gpt-image-2` 当聊天模型使用，会被发到：

```text
/v1/chat/completions
```

正确生图接口应为：

```text
/v1/images/generations
```

Open WebUI 图片生成设置：

```text
图像生成：开
图像提示词生成：建议先关闭
图像生成引擎：OpenAI
OpenAI 接口地址：http://newapi:3000/v1
OpenAI 接口密钥：sk-[REDACTED_IMAGE_TOKEN]
模型：gpt-image-2
图片尺寸：按需设置
额外参数：{}
```

验证命令：

```bash
curl http://localhost:3000/v1/images/generations \
  -H "Authorization: Bearer sk-[REDACTED_NEWAPI_TOKEN]" \
  -H "Content-Type: application/json" \
  -d '{"model":"gpt-image-2","prompt":"a red cube on a white table","size":"1024x1024"}'
```

## 10. Open WebUI 配置

### 10.1 基础连接

`[已确认]` Open WebUI 调 NewAPI：

```text
OPENAI_API_BASE_URL=http://newapi:3000/v1
OPENAI_API_KEY=sk-[REDACTED_NEWAPI_TOKEN]
```

注意：

- Open WebUI 填的是 NewAPI token，不是 CPA key。
- NewAPI token 控制额度、分组、可用模型。
- 如果多个 Open WebUI 用户共用一个 NewAPI token，NewAPI 只能看到同一个 `token_name` 的总消耗。
- 小圈邀请制阶段不要求普通用户登录 `api.example.com`；普通用户只登录 `chat.example.com`。

### 10.2 注册审核与单 Token 治理

`[建议，待服务器执行]` Open WebUI 账号策略：

```yaml
ENABLE_SIGNUP: "true"
DEFAULT_USER_ROLE: pending
ENABLE_DIRECT_CONNECTIONS: "false"
ENABLE_API_KEYS: "false"
USER_PERMISSIONS_FEATURES_API_KEYS: "false"
BYPASS_MODEL_ACCESS_CONTROL: "false"
```

含义：

- 允许新用户注册，但默认进入 `pending`，管理员批准前不能直接使用模型。
- 关闭普通用户 Direct Connections，用户不能自己填 OpenAI / Gemini / CPA key。
- 关闭普通用户 Open WebUI API Key 自助能力，避免绕过模型权限。
- 不绕过模型访问控制，模型可见性由 Open WebUI 管理员按组授权。

注意：Open WebUI 的部分配置是 PersistentConfig，已有实例可能以数据库保存值为准。生产服务器改 Compose 后，还要进入 Open WebUI 管理后台确认同名开关。

### 10.3 A 方案：单全局 NewAPI token

当前日志显示：

```text
userId=1
token_name="test1"
group="svip"
```

含义：

- `[已确认]` Open WebUI 请求通过同一个 NewAPI token 进入。
- `[已确认]` 当前 Open WebUI 用户组不能直接绑定不同 NewAPI token。
- `[最终取舍]` 采用 A 方案：一个 Open WebUI 实例 + 一个全局 NewAPI token。
- `[建议]` 用户组只做账号审核、功能权限、资源可见性管理；成本和额度先由 NewAPI 全局 token + 日志人工观察。

| Open WebUI 组 | 用途 | 模型范围 | 备注 |
|---|---|---|---|
| `basic` | 普通小圈成员 | DeepSeek、低成本模型 | 默认批准组 |
| `vip` | 可信用户 / 高质量聊天 | basic + `gpt-5.5` | 人工观察用量 |
| `svip` | 高推理 / 高成本用户 | vip + `gpt-5.5-high`、生图 | 谨慎加入 |
| `admin` | 管理员 / 测试 | 全部模型和后台资源 | 仅管理员 |

落地步骤：

1. 在 NewAPI 创建一个 Open WebUI 全局调用 token，写入 `.env` 的 `NEWAPI_MASTER_KEY`。
2. Open WebUI 全局连接使用 `http://newapi:3000/v1` + `NEWAPI_MASTER_KEY`。
3. 新用户注册后保持 `pending`，管理员批准后改为 `user` 并加入 `basic` / `vip` / `svip`。
4. 用户组权限只用于控制功能入口、知识库、提示词、工具、分享等能力。
5. 如果当前 Open WebUI 版本无法稳定按组限制模型，则不要承诺模型级隔离；高成本模型先只给管理员或可信小圈使用。
6. 未来若需要严格分账，再升级为 B 方案（多 Open WebUI 实例）或 C 方案（token broker）。

### 10.4 图片生成设置

Open WebUI 图片设置建议：

```text
图像生成：开
图像提示词生成：先关闭
图像生成引擎：OpenAI
OpenAI 接口地址：http://newapi:3000/v1
OpenAI 接口密钥：sk-[REDACTED_NEWAPI_TOKEN]
模型：gpt-image-2
图片尺寸：1024x1024
额外参数：{}
```

其中 `OpenAI 接口密钥` 可填写专用图片 token；如果先采用 A 方案简化运维，也可以暂时复用全局 NewAPI token，但要在 NewAPI 日志中重点观察生图费用。

验证时必须看到 NewAPI 日志：

```text
POST /v1/images/generations
```

如果仍是：

```text
POST /v1/chat/completions
```

说明还没有进入真正的图片生成流程。

## 11. 部署流程

### 11.1 首次部署

```bash
cd /opt/Serve

cp .env.example .env
nano .env
```

填入：

```env
DB_USER=ai_admin
DB_PASS=[强密码]
CF_TUNNEL_TOKEN=[Cloudflare Tunnel Token]
NEWAPI_MASTER_KEY=
```

先启动 PostgreSQL 和 NewAPI：

```bash
docker compose config --quiet
docker compose up -d postgres newapi
docker compose ps
docker compose logs -f --tail=100 newapi
```

进入 NewAPI 创建调用令牌，回填：

```env
NEWAPI_MASTER_KEY=sk-[REDACTED_NEWAPI_TOKEN]
```

再启动 Open WebUI 和 Cloudflared：

```bash
docker compose up -d open-webui cloudflared
docker compose ps
```

### 11.2 修改 .env 后生效

```bash
docker compose up -d --force-recreate newapi open-webui
```

不要只执行：

```bash
docker restart newapi
```

因为 `.env` 变更需要 Compose 重新创建容器。

## 12. 验证清单

### 12.1 容器状态

```bash
docker compose ps
```

预期：

```text
postgres   healthy
newapi     healthy
open-webui healthy 或 running
cloudflare-tunnel running
```

### 12.2 NewAPI 状态

```bash
curl http://localhost:3000/api/status
curl https://api.example.com/api/status
```

### 12.3 Open WebUI 到 NewAPI

在 Open WebUI 中选择 NewAPI 可用模型，发起聊天。NewAPI 日志应出现：

```text
POST /v1/chat/completions
```

### 12.4 上游模型

DeepSeek：

```bash
curl https://api.example.com/v1/chat/completions \
  -H "Authorization: Bearer sk-[REDACTED_NEWAPI_TOKEN]" \
  -H "Content-Type: application/json" \
  -d '{"model":"deepseek-chat","messages":[{"role":"user","content":"ping"}],"stream":false}'
```

CPA：

```bash
curl https://api.example.com/v1/chat/completions \
  -H "Authorization: Bearer sk-[REDACTED_NEWAPI_TOKEN]" \
  -H "Content-Type: application/json" \
  -d '{"model":"gpt-5.5-high","messages":[{"role":"user","content":"ping"}],"stream":false}'
```

### 12.5 代理链路

```bash
docker run --rm --network ai-platform_ai-net \
  curlimages/curl:8.10.1 \
  -x http://172.18.0.1:7890 \
  -I --max-time 10 http://www.gstatic.com/generate_204
```

预期：

```text
HTTP/1.1 204 No Content
```

## 13. 历史问题复盘

| 问题 | 现象 | 根因 | 修复方式 | 验证 |
|---|---|---|---|---|
| 系统未正常启动 | QEMU 进入 initramfs，`No init found` | 初始系统未正确安装或引导异常 | 使用面板一键安装 Ubuntu 22.04 | 能 root 登录 Ubuntu |
| SSH Remote 失败 | `Could not resolve hostname root` | SSH 目标格式/配置错误 | 使用 `root@<server-public-ip>` | Cursor 成功连入 |
| apt 被锁 | `Could not get lock ... unattended-upgr` | Ubuntu 首次自动更新 | 等待 unattended-upgrade 完成 | `apt update` 正常 |
| Docker daemon 未运行 | `Cannot connect to docker.sock` | Docker 服务未启动 | `systemctl enable --now docker` | `docker compose config --quiet` 正常 |
| NewAPI 服务名拼接错误 | `no such service: newapidocker` | 命令粘贴少换行 | 分开执行 `docker compose logs ... newapi` | 日志正常 |
| NewAPI 连接 PG 异常 | SQL DSN 被错误解析 | 缺 `postgresql://` 前缀 | 使用 `postgresql://${DB_USER}...` | NewAPI healthy |
| 首启数据库不存在 | `newapi_db` / `openwebui_db` 缺失 | PostgreSQL 首次初始化未创建多库 | 使用 `init.sql` | PG 初始化后库存在 |
| NewAPI 经代理 malformed response | `malformed HTTP response` | Go HTTP/2 与代理/上游协议兼容问题 | 加 `GODEBUG=http2client=0` 并重建 NewAPI | DeepSeek 请求成功 |
| DeepSeek 原生类型失败 | `Bad Request` | NewAPI DeepSeek 类型兼容问题 | 改用 OpenAI Compatible 类型 | `deepseek-chat` 成功 |
| Clash 订阅 curl 失败 | `403` / `404` / 空文件 | URL 错误或 UA 被限制 | `curl -fL -A "ClashforWindows/0.20.39"` 先写 `/tmp` 验证 | `clash -t -d /etc/clash` 成功 |
| Clash 被公网偷流量 | 流量异常消耗 | 监听 `*:7890` / `0.0.0.0:7890` | 改为 `bind-address: 172.18.0.1` | `ss` 不出现 `*:7890` |
| 容器访问 Clash timeout | `dial tcp 172.18.0.1:7890 timeout` | 防火墙未放行 Docker 网桥到宿主机代理 | 加 iptables 规则并 systemd 持久化 | 容器 curl 返回 204 |
| `host-gateway` 不通 | `host.docker.internal -> 172.17.0.1` | 自定义网桥实际网关为 `172.18.0.1` | `extra_hosts` 固定写 `172.18.0.1` | `getent hosts` 返回 `172.18.0.1` |
| NewAPI cookie 报错 | `securecookie: value is not valid` | 重建后浏览器旧 session cookie 失效 | 清 cookie / 重新登录 | 管理后台正常 |
| NewAPI SMTP 错误 | `invalid SMTP account` | 未配置 SMTP | 暂不绑定邮箱或配置 SMTP | 邮箱功能正常 |
| Cloudflare Tunnel token 泄露 | token 出现在聊天记录 | 凭证暴露 | 轮换 Tunnel token | 新 token 生效 |
| Clash 订阅泄露 | 订阅链接出现在聊天记录 | 凭证暴露 | 更换订阅链接并清理旧配置 | 新订阅可拉取 |
| OpenWebUI 生图失败 | `gpt-image-2 only supported on /v1/images/generations` | 生图模型被当聊天模型调用 | 使用图片生成入口，关闭提示词生成测试 | 日志出现 `/v1/images/generations` |
| Cloudflare Email Routing 冲突 | 要删除 Spaceship MX/TXT | 旧邮箱服务占用 MX | 选择 Cloudflare Routing 则删除旧 MX | MX 指向 Cloudflare |
| Email 验证频率限制 | `Verification email has been sent too recently` | 短时间重复发验证邮件 | 等待后重发，检查垃圾箱 | 目标邮箱 verified |

## 14. 历史冲突与最终取舍

| 历史配置 | 问题 | 最终取舍 |
|---|---|---|
| Clash 监听 `*:7890` | 容器可用，但公网可偷流量 | 改为 `172.18.0.1:7890` |
| `host.docker.internal:host-gateway` | 本机解析为 `172.17.0.1`，与 `ai-net` 不一致 | 固定 `host.docker.internal:172.18.0.1` |
| NewAPI 原生 DeepSeek 渠道 | Bad Request | 使用 OpenAI Compatible |
| DeepSeek 直接 HTTP/2 | malformed response | `GODEBUG=http2client=0` |
| OpenWebUI 直接连上游 | 难统一计费和代理 | 统一走 NewAPI |
| `api.example.com` 加 Access | API 客户端无法直接 Bearer 调用 | API 域名不挂 Access |
| `admin.example.com` 不保护 | 管理后台暴露风险 | 加 Cloudflare Access 邮箱 OTP |
| 图片模型放入普通聊天 | 触发 `/v1/chat/completions` 报错 | 图片生成必须走 `/v1/images/generations` |

## 15. 运维建议

`[建议]` 安全：

- 所有暴露过的 NewAPI token、Cloudflare Tunnel token、Clash 订阅链接都应轮换。
- `7890`、`3000`、`8080`、`5432` 不应通过服务商安全组对公网开放。
- `admin.example.com` 保持 Cloudflare Access 保护。
- `api.example.com` 只依赖 Bearer Token，token 分组和额度要严格控制。

`[建议]` 计费：

- `gpt-5.5-high` 已确认传递 `reasoning_effort=high`，且实际成本更高。
- high / xhigh 模型应设置更高倍率。
- 普通用户不要默认开放 high / xhigh / image 模型。

`[建议]` 备份：

```bash
/opt/Serve/backup/pg_dump.sh
```

建议接入 cron，每日备份 PostgreSQL。

`[建议]` 发布前最终检查：

```bash
cd /opt/Serve
docker compose config --quiet
docker compose ps
ss -lntup | grep -E '7890|3000|8080|5432'
curl https://api.example.com/api/status
docker run --rm --network ai-platform_ai-net curlimages/curl:8.10.1 \
  -x http://172.18.0.1:7890 \
  -I --max-time 10 http://www.gstatic.com/generate_204
```

安全预期：

```text
7890 只监听 172.18.0.1
3000/8080/5432 不监听公网
Cloudflare Tunnel 正常连接
NewAPI / Open WebUI 通过域名访问正常
```
