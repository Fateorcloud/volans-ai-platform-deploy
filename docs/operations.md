# 运维手册

## 服务状态

```bash
cd /opt/lobehub
docker compose ps
docker compose logs -f lobehub
docker compose logs -f lobe-postgres
docker compose logs -f lobe-rustfs
docker compose logs -f lobe-searxng
```

## 验证

```bash
sudo bash deploy.sh verify
# 或在已部署目录：
sudo /opt/lobehub/scripts/healthcheck.sh
```

验证脚本会检查：

```text
Compose 服务状态
本机端口是否误绑到公网
PostgreSQL、Redis、RustFS、SearXNG 基础健康
LobeHub HTTP 入口
```

## 启停与更新

```bash
cd /opt/lobehub
docker compose pull
docker compose up -d
docker compose restart lobehub
```

更新前建议先备份：

```bash
sudo bash /opt/lobehub/backup/lobehub_backup.sh
```

## 备份

```bash
sudo bash deploy.sh backup
```

默认输出：

```text
/opt/lobehub/backup/postgres_lobechat_YYYY-MM-DD_HHMMSS.sql.gz
/opt/lobehub/backup/rustfs_data_YYYY-MM-DD_HHMMSS.tar.gz
```

Redis 使用 AOF 持久化，备份脚本会触发一次 `BGSAVE`。

## 修复模板文件

```bash
sudo bash deploy.sh repair --yes
```

该命令会重新渲染 compose、bucket policy、SearXNG 配置和健康检查脚本，但保留
已有 `.env` 与数据目录。

## 常用端口

本机测试阶段这些端口必须只监听 `127.0.0.1`：

```text
3210  LobeHub
9000  RustFS S3 API
9001  RustFS console
15432 PostgreSQL
16379 Redis
18080 SearXNG
```
