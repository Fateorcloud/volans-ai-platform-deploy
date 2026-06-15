# 运维手册

## 验证

```bash
sudo bash deploy.sh verify
# 或
sudo bash verify.sh
```

重点看：

```text
postgres/newapi/open-webui healthy
gpt-image-playground/caddy-image/cloudflare-tunnel running
xui-3xui running
7890 只监听 172.18.0.1 和 172.19.0.1
Open WebUI enable_signup=true
host direct 与 Docker via privoxy 是不同出口
xui direct 与 xui via privoxy 是不同出口
```

## 主平台

```bash
cd /opt/Serve
docker compose ps
docker compose config --quiet
docker compose up -d
docker compose logs -f newapi
docker compose logs -f open-webui
docker compose logs -f caddy-image
docker compose logs -f cloudflared
```

## 3xui

```bash
cd /opt/Serve/xui
docker compose ps
docker compose config --quiet
docker compose up -d --force-recreate xui
docker compose logs -f xui
docker port xui-3xui
```

## NAT 代理链

```bash
systemctl status nat-socks --no-pager
systemctl status privoxy --no-pager
systemctl status ai-proxy-firewall --no-pager

systemctl restart nat-socks
systemctl restart privoxy
systemctl restart ai-proxy-firewall
```

## 备份

手动备份：

```bash
sudo bash backup.sh
```

备份文件：

```text
/opt/Serve/backup/postgres_all_YYYY-MM-DD_HHMMSS.sql.gz
```

## 修复代理

```bash
sudo bash deploy.sh proxy --yes
```

这会重装或修复：

```text
nat-socks.service
privoxy
ai-proxy-firewall.service
```

## 修复项目文件

```bash
sudo bash deploy.sh repair --yes
```

此命令会保留已有 `.env` 和数据目录。
