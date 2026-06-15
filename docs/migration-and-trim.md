# 迁移与裁剪 Runbook

这份文档用于把现有部署迁到另一台服务器，或在裁剪组件前确认不会破坏核心平台。文档只使用占位符，不记录真实服务器、token、密码或私有域名。

## 1. 模块边界

| 模块 | 文件/目录 | 是否核心 | 可裁剪条件 |
|---|---|---|---|
| PostgreSQL | `/opt/Serve/pg_data`、`backup.sh` | 是 | 不可裁剪，只能迁移或恢复 |
| NewAPI | `newapi` 容器、`newapi_data` | 是 | 不可裁剪 |
| Open WebUI | `open-webui` 容器、`open-webui_data` | 是 | 不可裁剪 |
| cloudflared | `cloudflare-tunnel` 容器 | 是 | 仅当改用其他入口网关时可替换 |
| GPT Image Playground | `gpt-image-playground`、`caddy-image` | 否 | 不提供图片入口时可裁剪 |
| 3xui | `/opt/Serve/xui`、`xui-3xui` | 否 | 不需要 Reality 节点或代理面板时可裁剪 |
| NAT egress proxy | `nat-socks.service`、Privoxy、`ai-proxy-firewall` | 取决于上游 | 如果上游 API 可直连，可裁剪 |
| Notes/static sites | 独立站点目录和 Nginx | 否 | 应作为独立项目迁移，不和 AI 平台绑定 |

## 2. 迁移顺序

1. 在旧服务器执行 `sudo bash deploy.sh backup`。
2. 将备份文件复制到新服务器或离线位置。
3. 在新服务器克隆仓库并编辑 `.env`。
4. 执行 `sudo bash deploy.sh fresh --yes`。
5. 如果需要历史数据，在维护窗口内恢复 PostgreSQL 备份。
6. 如需保留上传文件、知识库或本地 artifacts，再迁移 `open-webui_data` 中对应文件。
7. 在 Cloudflare 中把 tunnel public hostnames 指向新 tunnel。
8. 运行 `sudo bash deploy.sh verify`。

## 3. 必做备份

逻辑备份：

```bash
sudo bash deploy.sh backup
```

检查备份文件：

```bash
ls -lh /opt/Serve/backup/
gzip -t /opt/Serve/backup/postgres_all_*.sql.gz
```

最低要求：至少做一次恢复演练，再把旧服务器下线。

## 4. 可裁剪项

### 图片站

停止：

```bash
cd /opt/Serve
docker compose stop gpt-image-playground caddy-image
```

确认不再需要后再移除容器和 Caddy 的 80/443 暴露策略。不要删除 `newapi` 里的图片渠道，除非确认 Open WebUI 也不再使用图片生成。

### 3xui

停止：

```bash
cd /opt/Serve/xui
docker compose down
```

同时移除：

```text
Cloudflare proxy panel hostname
UFW Reality inbound port
xui_default network attachment
```

### NAT egress proxy

裁剪前先确认 NewAPI 上游模型可直连：

```bash
cd /opt/Serve
docker compose exec newapi sh -lc 'wget -S -O- --timeout=10 https://www.gstatic.com/generate_204 2>&1 | head'
```

如果上游仍需要代理，不要停 `nat-socks.service`、Privoxy 或 `ai-proxy-firewall.service`。

## 5. Cloudflare 策略

推荐拆分：

```text
chat.example.com  -> open-webui:8080，可选 Access
admin.example.com -> newapi:3000，必须 Access
api.example.com   -> newapi:3000，不加 Access，只靠 Bearer token
proxy.example.com -> xui-3xui:12053，必须 Access
image.example.com -> DNS only 到服务器 80/443，由 Caddy Basic Auth 保护
```

API 域名的保护应放在 NewAPI token、IP 白名单、额度、WAF/rate limit，而不是 Cloudflare Access 登录层。

## 6. 下线旧服务器前检查

```bash
sudo bash deploy.sh verify
curl -I https://chat.example.com/
curl -I https://api.example.com/v1/models
curl -I https://image.example.com/
```

确认：

- `chat` 指到新服务器。
- `api` 不再出现 Cloudflare Access 登录跳转。
- 新服务器可以通过 NewAPI 调用至少一个低成本模型。
- 已经有一份可解压、可恢复的 PostgreSQL 备份。
- 私有 `.env`、备份包、SSH key、xui 数据库没有进入 Git。
