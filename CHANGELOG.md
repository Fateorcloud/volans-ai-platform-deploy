# 工作日志 / Change Log

> 用途：每次对本仓库做出有意义的改动时，按时间倒序追加一段；方便次日/下周复盘追溯决策链路。

---

## 2026-04-23 — 初版方案评审 + 首次决策回填

### 背景

用户提交初版"香港自部署 AI 平台"方案（Open WebUI + NewAPI + PostgreSQL + Cloudflare Tunnel，四容器 + 宿主机代理分流），请求系统性评审。

### 评审结论（共 11 项改动）

**必改（会导致启动失败或行为错误）：**

| ID   | 问题                                                 | 修复方案                                                                 |
| ---- | ---------------------------------------------------- | ------------------------------------------------------------------------ |
| B1   | `HTTP_PROXY=http://172.17.0.1:7890` 在自定义网桥不通 | 改用 `host.docker.internal:host-gateway` + `extra_hosts`                 |
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
- [ ] 宿主机 Clash 配置是否真正监听 `0.0.0.0:7890`（`ss -tlnp | grep 7890`）
- [ ] 镜像版本是否需要从 `latest` / `main` 锁定到具体 tag（目前 `.env.example` 给的是 placeholder）
- [ ] 是否需要启用 `--profile browser`（建议第一周先不开，观察内存曲线）
- [ ] 域名 DNS 是否全部指到 Cloudflare 名字服务器，CF Access 策略是否只对 `admin.*` 生效

### 复盘检查清单（Run book）

部署当天按下面顺序跑一遍即可：

```bash
# 0. 宿主机
sudo systemctl status clash               # active (running)
curl -x http://127.0.0.1:7890 -I https://www.gstatic.com/generate_204  # HTTP/2 204
ss -tlnp | grep 7890                      # 监听 *:7890 或 0.0.0.0:7890

# 1. 栈
cd /opt/ai-platform
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
