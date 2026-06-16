# 工作日志 / Change Log

> 用途：每次对本仓库做出有意义的改动时，按时间倒序追加一段；方便次日/下周复盘追溯决策链路。

---

## 2026-06-15 — 部署模板整理与公开/私有文档分层

### 背景

线上部署已经从最初的核心四容器演化为核心 AI 平台、可选图片站、可选 xui、独立 notes 站共存。为了后续裁剪服务器，并确保项目能在另一台服务器直接部署，本次把仓库重新整理成可迁移模板。

### 本次落地

- `docker-compose.yml` 收敛为默认核心栈：PostgreSQL、NewAPI、Open WebUI、cloudflared，以及可选 Playwright profile。
- 新增 `docker-compose.image.yml`，把图片 playground + Caddy 图片站拆成显式 `image` profile。
- 新增 `xui/docker-compose.yml` 与 `docker-compose.xui-tunnel.yml`，xui 变成独立可选栈，不再让核心部署依赖外部 `xui_default` 网络。
- 新增 `systemd/ai-proxy-firewall.service` 与脚本，只允许 Docker 网桥访问宿主机代理端口。
- `scripts/install-server.sh` 改为新服务器 bootstrap：安装 Docker、同步到 `/opt/Serve`、安装备份 cron、代理探活 cron、代理防火墙 service，并生成 `.env` 模板。
- `.env.example` 扩展为核心必填、WebUI 治理、Web 搜索、Cloudflare、可选图片站、可选 xui、版本 pin 分区。
- 新增 `AUTO-DEPLOY-PUBLIC.md` 作为 GitHub 安全的自动部署文档。
- 新增 `AUTO-DEPLOY-PRIVATE.md` 作为本机私有部署记录，并通过 `.gitignore` 排除。
- 公开文档中的真实域名、服务器 IP、本地路径已替换为 `example.com`、`<server-public-ip>`、`<local-repo-path>` 等占位符。

### 当前注意事项

- 公开 GitHub 文档只描述推荐目标态：`admin.*` 走 Cloudflare Access，`api.*` 不走 Access、只靠 Bearer token。
- 如果某台现有服务器上 `api.*` 仍被 Cloudflare Access 保护，应先按私有 runbook 记录为偏差，再决定是否修复。
- 备份链要以 `backup/pg_dump.sh` 的逻辑备份和恢复演练为准，不要只依赖宿主机目录存在。

---

## 2026-04-28 — 小圈邀请制与 A 方案单 Token 治理

### 背景

平台已从“管理员自用已跑通”进入“小圈邀请制”阶段。生产配置以香港服务器 `/opt/Serve` 为准，本地仓库只同步模板、手册和 SOP，避免本地旧配置反向污染服务器。

### 本次落地

- Open WebUI 注册策略改为：允许注册，但默认 `pending`，必须管理员批准后加入用户组。
- 实测发现 Open WebUI 用户组本身不能直接绑定不同 NewAPI token；root 个人 token 也不会自动继承给用户组。
- 令牌策略最终调整为 A 方案：单 Open WebUI + 一个全局 NewAPI token。
- Open WebUI 连接策略：全局 OpenAI-compatible 连接统一指向 `http://newapi:3000/v1`，使用 `NEWAPI_MASTER_KEY`。
- 用户组只用于账号审核、功能权限、知识库/提示词/工具/分享等能力控制；不再承诺按用户组自动切换 NewAPI token。
- 如果未来需要严格分账，再升级为 B 方案（多 Open WebUI 实例）或 C 方案（token broker）。
- 图片生成状态改为已解决：Open WebUI 图片生成设置中使用单独图片 token，正确请求路径应为 `/v1/images/generations`。
- 本地 `docker-compose.yml` / `docker-compose-S.yml` 收敛到服务器最终代理方案：`host.docker.internal:172.18.0.1`，`newapi` 保留 `GODEBUG=http2client=0`。

### 关键安全取舍

- Clash 不再推荐监听 `0.0.0.0:7890` 或 `*:7890`。
- 最终方案是宿主机 Clash 只监听 `172.18.0.1:7890`，并通过 iptables 只放行 Docker 网桥访问。
- `admin.example.com` 继续使用 Cloudflare Access 邮箱验证码保护；`api.example.com` 不挂 Access，只靠 NewAPI Bearer token 和 NewAPI 侧权限/额度限制。

### 待服务器执行

- [ ] 在 `/opt/Serve/docker-compose.yml` 的 `open-webui.environment` 加入注册/权限环境变量。
- [ ] `docker compose config --quiet`
- [ ] `docker compose up -d --force-recreate open-webui`
- [ ] 在 Open WebUI 后台确认注册、Direct Connections、API Keys、模型访问控制开关。
- [ ] 在 Open WebUI 后台确认测试用户已从 `pending` 改为 `user`，并加入正确用户组。

---

## 2026-04-25 — 香港服务器实机部署 + 域名上线 + 密钥轮换

### 背景

把本地 `<local-repo-path>` 方案部署到香港 Ubuntu 22.04.3 服务器（`/opt/Serve`），完成 Docker 栈、宿主机代理、Cloudflare Tunnel、NewAPI、Open WebUI 的端到端上线。

### 实际完成

- 服务器一键安装 Ubuntu 22.04.3 LTS，解决初始 `(initramfs)` 启动失败问题。
- 安装 Docker Engine `29.4.1` 与 Docker Compose `v5.1.3`。
- 上传并启动 `/opt/Serve`，`postgres`、`newapi`、`open-webui`、`cloudflared` 均已运行。
- 配置 Cloudflare Tunnel `example-tunnel`，三条 hostname 已生效：
  - `admin.example.com` → `http://newapi:3000`
  - `api.example.com` → `http://newapi:3000`
  - `chat.example.com` → `http://open-webui:8080`
- 给 `admin.example.com` 启用 Cloudflare Access 邮箱一次性验证码；`api.example.com` 保持无 Access，只靠 NewAPI Bearer token。
- 安装并托管 Mihomo/Clash。早期曾监听 `*:7890`，后续已修正为 `172.18.0.1:7890`，容器通过 `host.docker.internal:7890` 出站。
- 完成 Clash 订阅链接轮换、Cloudflare Tunnel token 轮换、NewAPI 调用 token 轮换。
- 公网 API 已验证：`https://api.example.com/v1/chat/completions` 调用 `deepseek-v4-pro` 成功返回。

### 关键排障结论

- `7890` 是代理端口，不是网页后台；浏览器打不开属于正常现象。最终安全配置只监听 `172.18.0.1:7890`。
- NewAPI 的 `DeepSeek` 专用渠道类型在当前版本会向 DeepSeek 返回上游 `Bad Request`；实测应使用 `OpenAI` 兼容类型。
- DeepSeek 渠道配置为：
  - 类型：`OpenAI`
  - API 地址：`https://api.deepseek.com`
  - 模型：优先 `deepseek-v4-pro`，按需添加 `deepseek-reasoner` / `deepseek-chat`
- `newapi` 经代理访问 DeepSeek 时遇到过 `malformed HTTP response`，通过在 `newapi.environment` 添加 `GODEBUG=http2client=0` 并 force recreate 规避。
- `deepseek-v4-flash` 通过 API 返回 `model_not_found` 时，不是公网链路故障，而是 NewAPI 渠道模型列表或 `default` 分组未开放该模型。

### 安全状态

- `.env`、NewAPI token、Cloudflare Tunnel token、Clash 订阅链接均不应提交到 git。
- 本次对话中曾贴出过调用 token、Tunnel token、Clash 订阅链接，已按“视为泄露”原则完成轮换。
- 服务商安全组应继续保持：不要公网开放 `7890`、`3000`、`8080`、`5432`。

### 后续建议

- [ ] 启用 `backup/pg_dump.sh` 每日备份，并确认备份文件可恢复。
- [ ] 启用 `systemd/proxy-healthcheck.sh` 定时探活 Clash。
- [ ] 在 Open WebUI 里只暴露 3-6 个精选模型，用中文模型预设降低模型列表复杂度。
- [ ] 将 `NEWAPI_VERSION`、`OPENWEBUI_VERSION`、`CLOUDFLARED_VERSION` 从 `latest/main` 锁到实测稳定 tag。

---

## 2026-04-23 — 初版方案评审 + 首次决策回填

### 背景

用户提交初版"香港自部署 AI 平台"方案（Open WebUI + NewAPI + PostgreSQL + Cloudflare Tunnel，四容器 + 宿主机代理分流），请求系统性评审。

### 评审结论（共 11 项改动）

**必改（会导致启动失败或行为错误）：**

| ID   | 问题                                                 | 修复方案                                                                 |
| ---- | ---------------------------------------------------- | ------------------------------------------------------------------------ |
| B1   | `HTTP_PROXY=http://172.17.0.1:7890` 在自定义网桥不通 | 初版改用 `host-gateway`；实机最终固定为 `host.docker.internal:172.18.0.1` |
| B2   | `SQL_DSN` 缺 `postgresql://` 前缀，被当 MySQL 解析   | 加前缀                                                                   |
| B3   | 未显式创建 `newapi_db` / `openwebui_db`              | 写 `init.sql`，`POSTGRES_USER` 入口自动执行                              |
| B4   | `NEWAPI_MASTER_KEY` 鸡生蛋                           | README 规范化：先起 NewAPI → 登录建令牌 → 回填 .env → compose up -d 重建 |
| B5   | `PERSONAL_BROWSER_HEADLESS` 在 Open WebUI 官方文档无 | 保留变量（用户坚持），同时显式设置 `WEB_LOADER_ENGINE=safe_web`          |

**强烈建议（稳定性 / 可维护性）：**

| ID   | 问题                                   | 修复方案                                             |
| ---- | -------------------------------------- | ---------------------------------------------------- |
| S1   | 镜像用 `:latest` / `:main` 无法复现     | 全部改用 `.env` 变量控制版本                         |
| S2   | `depends_on` 无 healthcheck，首启炸锅  | Postgres 加 `pg_isready` + 下游用 `service_healthy`  |
| S3   | `NO_PROXY` 只写服务名，DNS 解析前会漏  | 扩到 `172.16.0.0/12,10.0.0.0/8` 全 Docker 网段       |
| S4   | NewAPI 是否外暴（待决策）              | ⏭ 见下方"用户决策"                                   |
| S5   | 宿主机代理崩溃 = 全栈瘫痪              | 提供 systemd unit + 定时 curl 探活脚本               |

**锦上添花：**

- 日志轮转 `max-size:50m, max-file:3`
- 资源 limits（PG 1G / WebUI 2G / NewAPI 512M / Playwright 1G）
- `backup/pg_dump.sh` 每日备份 + 可选 rclone 异地
- Embedding / Reranker 显式路由到 NewAPI
- 删除 `version: '3.8'`（Compose v2 已 obsolete）

### 用户决策回填（本次）

> 用户回复两点：

1. **S4 — NewAPI 外暴**：设置**两条域名**；一条管理用（CF Access 加固），一条 API 用（凭 Token 访问）。
   - 落地：三 hostname 方案（`chat.*` + `admin.*` + `api.*`），其中 `admin.*` 和 `api.*` 指向同一个 `newapi:3000` 容器，通过 CF 边缘按 hostname 分策略。
   - 写入 README "步骤 2"，附带 CF Access 策略示例和 WAF / IP 白名单加固建议。

2. **B5 — 浏览器模式**：4G 内存下先保持 `PERSONAL_BROWSER_HEADLESS=true`，出现 OOM 或解析失败再拆 browserless。
   - 落地：`docker-compose.yml` 里 `open-webui.environment` 显式写入 `PERSONAL_BROWSER_HEADLESS: "true"`，同时 `WEB_LOADER_ENGINE` 默认 `safe_web`；browserless 以 `profile: browser` 形式预置，一条 `docker compose --profile browser up -d` 即可切换。
   - README "浏览器抓取策略" 章节写明触发升级的三个观测信号。

### 本次产出的文件清单

```
docker-compose.yml                 # 主编排，已包含全部必改项 + 建议项
.env.example                       # 环境变量模板（secrets 占位）
.gitignore                         # 忽略 .env / 数据卷 / 备份
init.sql                           # 首启建两个库
README.md                          # 部署手册（含 bootstrap 鸡生蛋流程 + 三 hostname 配置 + 浏览器策略）
backup/pg_dump.sh                  # 每日 pg_dumpall + 保留 14 天 + 可选 rclone
systemd/clash.service              # 宿主机代理托管 unit
systemd/proxy-healthcheck.sh       # curl 探活 + 失败 systemctl restart
CHANGELOG.md                       # 本文件
```

### 未决 / 明日复盘时建议核对

- [ ] `.env` 真实密钥是否已填且强度足够（DB_PASS 建议 32 字符随机）
- [ ] Cloudflare Tunnel token 是否绑定到正确的账号 / zone
- [ ] 宿主机 Clash 配置是否只监听 `172.18.0.1:7890`（`ss -lntup | grep 7890`）
- [ ] 镜像版本是否需要从 `latest` / `main` 锁定到具体 tag（目前 `.env.example` 给的是 placeholder）
- [ ] 是否需要启用 `--profile browser`（建议第一周先不开，观察内存曲线）
- [ ] 域名 DNS 是否全部指到 Cloudflare 名字服务器，CF Access 策略是否只对 `admin.*` 生效

### 复盘检查清单（Run book）

部署当天按下面顺序跑一遍即可：

```bash
# 0. 宿主机
sudo systemctl status clash               # active (running)
curl -x http://172.18.0.1:7890 -I http://www.gstatic.com/generate_204  # HTTP/1.1 204
ss -lntup | grep 7890                     # 只应看到 172.18.0.1:7890，不应看到 *:7890

# 1. 栈
cd /opt/Serve
docker compose config --quiet             # 无 error
docker compose up -d postgres newapi
docker compose ps                         # postgres healthy，newapi healthy
docker compose logs --tail=80 newapi      # 无 connection refused

# 2. 登录 admin.your-domain.com 创建 channel + token，回填 .env
docker compose up -d open-webui

# 3. 端到端
curl https://api.your-domain.com/v1/models -H "Authorization: Bearer $NEWAPI_MASTER_KEY"
# 浏览器打开 https://chat.your-domain.com 聊天测试

# 4. 备份 smoke test
./backup/pg_dump.sh
ls -lh backup/
```

---

<!-- 下一次改动从这里向上追加 -->
