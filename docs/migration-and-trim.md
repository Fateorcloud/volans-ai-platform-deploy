# 迁移与裁剪 Runbook

这份文档用于把 LobeHub 部署迁移到另一台服务器，或从旧 AI 平台裁剪到新的轻量栈。
文档只使用占位符，不记录真实服务器、token、密码或私有域名。

## 模块边界

| 模块 | 路径/服务 | 是否核心 | 说明 |
|---|---|---|---|
| LobeHub | `lobehub` 容器 | 是 | 前端与服务端主应用 |
| PostgreSQL/PGVector | `postgres_data/` | 是 | 会话、用户、配置、知识库元数据 |
| Redis | `redis_data/` | 是 | 缓存、会话和后台任务辅助状态 |
| RustFS/S3 | `rustfs_data/` | 是 | 上传文件、图片和知识库对象 |
| SearXNG | `lobe-searxng` | 可选 | 联网搜索；不用搜索时可停用 |
| 旧 NewAPI/Open WebUI/图站 | GitHub `codex/legacy-ai-stack-backup` | 否 | 已备份，当前项目不再部署 |
| xui/NAT | `deploy.sh xui` / `deploy.sh nat-proxy` | 否 | 独立可选网络组件，不属于 AI 平台 |
| Notes/static sites | 独立目录和 Nginx | 无关 | 不属于本轮 AI 平台裁剪 |

## 从旧平台裁剪

第一轮不要删除旧目录和 volume。推荐顺序：

1. 确认旧 NewAPI/Open WebUI/图站/xui/NAT 链路已经备份到 GitHub 分支 `codex/legacy-ai-stack-backup`。
2. 保留旧服务器 `/opt/Serve`，不要自动删除 volume。
3. 新建 `/opt/lobehub` 并部署新栈。
4. 通过 SSH 隧道验证 LobeHub UI、模型调用、会话持久化和上传。
5. 如果仍需要 xui/NAT，使用 `deploy.sh xui` 和 `deploy.sh nat-proxy` 单独安装。
6. 验证通过后，只停止旧容器，不删除数据。
7. 观察一段时间后，再手动决定是否归档或删除旧栈。

停止旧容器示例：

```bash
cd /opt/Serve
docker compose stop
```

不要自动删除：

```text
pg_data/
newapi_data/
open-webui_data/
xui/
server-backups/
```

当前仓库也不应再保留 NewAPI、Open WebUI 或图站部署模板；需要旧方案时从
`codex/legacy-ai-stack-backup` 分支恢复。

## 迁移到第二台服务器

在旧服务器备份：

```bash
sudo bash /opt/lobehub/backup/lobehub_backup.sh
```

复制到新服务器：

```text
/opt/lobehub/.env
postgres_lobechat_*.sql.gz
rustfs_data_*.tar.gz
```

在新服务器部署空栈：

```bash
git clone https://github.com/<your-name>/volans-ai-platform-deploy.git
cd volans-ai-platform-deploy
cp .env.example .env
nano .env
sudo bash deploy.sh fresh --yes
```

恢复 PostgreSQL：

```bash
cd /opt/lobehub
gzip -dc /path/to/postgres_lobechat_YYYY-MM-DD_HHMMSS.sql.gz \
  | docker compose exec -T postgresql psql -U postgres lobechat
```

恢复 RustFS：

```bash
cd /opt/lobehub
docker compose stop rustfs
sudo rm -rf rustfs_data
mkdir -p rustfs_data
tar xzf /path/to/rustfs_data_YYYY-MM-DD_HHMMSS.tar.gz -C rustfs_data
docker compose up -d rustfs rustfs-init lobehub
```

最后验证：

```bash
sudo bash deploy.sh verify
```

## 下线旧服务器前检查

```bash
sudo bash deploy.sh verify
ssh -L 3210:127.0.0.1:3210 -L 9000:127.0.0.1:9000 <new-server>
```

确认：

- LobeHub 可以登录。
- 至少一个模型供应商调用成功。
- 新建会话后重启 compose，记录仍存在。
- 上传文件或图片路径可访问。
- 备份文件可解压。
- 私有 `.env`、API key、备份包没有进入 Git。
