# AI Platform — 香港自部署方案

Open WebUI + NewAPI + PostgreSQL + Cloudflare Tunnel，四容器自洽，通过宿主机代理分流出国访问海外大模型。

## 架构

```
Browser / Python / MATLAB
        │  HTTPS
        ▼
 Cloudflare Edge ── tunnel ──► cloudflared
                                    │ (ai-net docker bridge)
                     chat.*    ┌────┴────┐    api.*
                               │         │
                         open-webui ◄──► newapi ──► postgres
                               │         │
                               └─ HTTP_PROXY ─► host.docker.internal:7890
                                                       │
                                                       ▼
                                         Clash/v2ray (systemd on host)
                                                       │
                                                       ▼
                                             海外 LLM / Anyrouter
```

关键决策：
- 容器通过 `host.docker.internal:host-gateway` 找到宿主机代理（比硬编码 `172.17.0.1` 对自定义网桥安全）
- Postgres 用 healthcheck 把 `depends_on` 变成强依赖，避免首启炸锅
- Cloudflare Tunnel 用一条 tunnel + 双 hostname 同时暴露聊天前台和 OpenAI 兼容 API
- 镜像版本通过 `.env` 变量集中管理，方便统一升级

## 目录结构

```
Serve/
├── docker-compose.yml          # 主编排
├── .env.example                # 环境变量模板（复制为 .env）
├── .env                        # 真实密钥（git 忽略）
├── init.sql                    # 首次启动建两个库
├── .gitignore
├── README.md
├── backup/
│   └── pg_dump.sh              # PG 每日备份（宿主机 cron 调度）
└── systemd/
    ├── clash.service           # 宿主机代理托管
    └── proxy-healthcheck.sh    # 代理探活自愈脚本
```

## 部署步骤

### 步骤 0 — 宿主机准备

1. 安装 Docker Engine + Compose v2（BuildKit 自带）
2. 把 Clash/v2ray 的二进制和配置放好：
   ```bash
   sudo cp systemd/clash.service /etc/systemd/system/
   sudo systemctl daemon-reload
   sudo systemctl enable --now clash
   ```
3. **重要：Clash 配置里必须把混合端口监听在 `0.0.0.0:7890`，否则 Docker 容器访问不到**：
   ```yaml
   # /etc/clash/config.yaml
   mixed-port: 7890
   bind-address: "*"        # 等价于 0.0.0.0
   allow-lan: true
   ```
4. 放行宿主机防火墙对 Docker 网段（`172.16.0.0/12`）的入站到 `7890`；**不要**对公网开放此端口
5. 验证代理可用：
   ```bash
   curl -x http://127.0.0.1:7890 https://www.gstatic.com/generate_204 -I
   # 期望: HTTP/2 204
   ```
6. 装代理自愈定时任务（可选但推荐）：
   ```bash
   sudo crontab -e
   # 追加：
   * * * * * /opt/ai-platform/systemd/proxy-healthcheck.sh >> /var/log/proxy-health.log 2>&1
   ```

### 步骤 1 — 拉起基础栈（首次 bootstrap）

```bash
cp .env.example .env
# 编辑 .env：填 DB_USER / DB_PASS / CF_TUNNEL_TOKEN；NEWAPI_MASTER_KEY 先留空
nano .env

docker compose up -d postgres newapi
docker compose logs -f newapi
# 等到看到 server started on port 3000 就可以 Ctrl+C 退出日志
```

### 步骤 2 — 配置 Cloudflare Tunnel（双 hostname）

在 Cloudflare Zero Trust 控制台 → Networks → Tunnels，给你已经创建的 tunnel 加两条 Public Hostname：

| Subdomain | Service URL             | 用途                          |
| --------- | ----------------------- | ----------------------------- |
| `chat`    | `http://open-webui:8080`| 浏览器访问 Open WebUI         |
| `api`     | `http://newapi:3000`    | Python / MATLAB 脚本走这条    |

> 因为 `cloudflared` 容器和业务容器在同一个 `ai-net` 网桥上，所以 Service URL 可以直接写服务名；不需要暴露任何宿主机端口。

建议同时给 `api.*` 套一层 **Cloudflare Access**（Email OTP / Google SSO），这样即使 NewAPI 的令牌泄漏，攻击者也需要先过身份认证。

### 步骤 3 — 在 NewAPI 里完成渠道 & 令牌配置（解决鸡生蛋）

> **为什么单独一步：** Open WebUI 的 `OPENAI_API_KEY` 环境变量要求 NewAPI 已经存在有效令牌，但令牌只能在 NewAPI 启动后通过 Web UI 创建。顺序必须是：先起 NewAPI → 建令牌 → 回写 `.env` → 重建 Open WebUI。

1. 浏览器访问 `https://chat.your-domain.com`（此时还是跳 Cloudflare，Open WebUI 未起不要紧），换成直连 `https://<api 子域>` 进入 NewAPI 管理台
2. 默认账号 `root` / `123456`，**立即改密码**
3. Channels（渠道）→ 新建 → 选择 Anyrouter（或其他上游），填 base URL + key → 测试
4. Tokens（令牌）→ 新建 → 取个名字、额度不限 → 生成 → 复制出来的 `sk-xxx`
5. 编辑 `.env`：
   ```
   NEWAPI_MASTER_KEY=sk-从上一步复制的令牌
   ```
6. 重建 Open WebUI 让新变量注入：
   ```bash
   docker compose up -d open-webui
   ```

### 步骤 4 — 验证端到端

```bash
# 1. 容器都 healthy
docker compose ps

# 2. 从容器内走代理验证（这一步最容易踩坑，务必做）
docker compose exec newapi sh -c 'wget -qO- --timeout=10 https://www.gstatic.com/generate_204 -S' 2>&1 | head -20

# 3. 通过 NewAPI 调 OpenAI 兼容接口
curl https://api.your-domain.com/v1/chat/completions \
  -H "Authorization: Bearer $NEWAPI_MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"gpt-4o-mini","messages":[{"role":"user","content":"ping"}]}'

# 4. 浏览器打开 https://chat.your-domain.com 聊天 + RAG
```

### 步骤 5 — 启用定时备份

```bash
chmod +x backup/pg_dump.sh
sudo crontab -e
# 追加：
0 3 * * * /opt/ai-platform/backup/pg_dump.sh >> /var/log/pgdump.log 2>&1
```

## 可选：启用 Playwright 抓取 JS 重页面

默认用 Open WebUI 内置的 `safe_web` loader 已经足够。如果要做 SPA / 动态加载网页的 RAG，启用 sidecar：

```bash
# .env 里改：
WEB_LOADER_ENGINE=playwright
PLAYWRIGHT_WS_URL=ws://playwright:3000

# 启动 sidecar profile
docker compose --profile browser up -d
```

## 日常运维

| 场景                         | 命令                                                                 |
| ---------------------------- | -------------------------------------------------------------------- |
| 改 `.env` 后生效             | `docker compose up -d`（Compose 自动检测变更、平滑重建受影响容器）  |
| 查某服务日志                 | `docker compose logs -f --tail=200 newapi`                           |
| 拉新镜像并升级               | 改 `.env` 里的 `*_VERSION` → `docker compose pull && docker compose up -d` |
| 进 PG 交互                   | `docker compose exec postgres psql -U $DB_USER -d newapi_db`         |
| 手动备份                     | `./backup/pg_dump.sh`                                                |
| 恢复备份                     | `gunzip -c backup/pgdump_XXX.sql.gz \| docker compose exec -T postgres psql -U $DB_USER` |

## 常见陷阱 cheat-sheet

1. **代理不通**：99% 是宿主机 Clash 没监听 `0.0.0.0`；`netstat -tlnp \| grep 7890` 看第一列必须是 `0.0.0.0:7890` 或 `*:7890`
2. **NewAPI 连不上 PG**：忘记加 `postgresql://` 前缀，它会默认当 MySQL 解析
3. **改了 `.env` 不生效**：`docker restart newapi` **不会**重新读 `.env`；必须 `docker compose up -d`
4. **`docker compose up` 说 `postgres_db` 不存在**：删 `pg_data/` 目录重新跑（init.sql 只在空数据卷时执行一次）
5. **cloudflared 连不上内部服务**：tunnel ingress 的 Service URL 要用 **容器服务名**（`http://newapi:3000`），不是 `localhost`
6. **升级 Open WebUI 后登录异常**：version pin 要和数据库 migration 匹配，别跳版本；大版本升级前先跑 `pg_dump`

## 二期可选增强

- **代码沙盒隔离**：Open WebUI 内置 code interpreter 跑在 backend 容器里，想跑 EIT 重建算法之类的重活，建议接一个独立 Jupyter Kernel Gateway 容器
- **多用户 RBAC**：Open WebUI 默认已有；若需 SSO，叠加 Cloudflare Access 更省事
- **GPU 本地推理**：加 `nvidia/cuda` runtime 的本地 Ollama 容器，通过 NewAPI 作为一个 channel 挂进去
- **监控**：Prometheus + cAdvisor + Grafana 独立 profile
