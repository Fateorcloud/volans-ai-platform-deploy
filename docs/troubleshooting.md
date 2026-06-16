# 排障

## LobeHub 打不开

检查服务：

```bash
cd /opt/lobehub
docker compose ps
docker compose logs --tail=200 lobehub
```

检查本机端口：

```bash
curl -I http://127.0.0.1:3210/
ss -lntup | grep ':3210'
```

如果没有监听，先看 `lobehub` 日志里的数据库迁移或环境变量错误。

## Compose 配置失败

```bash
cd /opt/lobehub
docker compose config --quiet
```

常见原因：

```text
.env 不存在
必填 secret 仍是 CHANGE_ME
AUTH_SECRET 包含空格但没有加引号
端口变量写成了非数字
```

## 数据库连接失败

LobeHub 使用 host network，连接的是宿主机 loopback：

```text
postgresql://postgres:<password>@127.0.0.1:15432/lobechat
```

检查：

```bash
cd /opt/lobehub
docker compose exec -T postgresql pg_isready -U postgres
ss -lntup | grep ':15432'
```

## 上传或图片不可用

第一阶段 `.env` 默认：

```env
S3_ENDPOINT=http://127.0.0.1:9000
S3_ENABLE_PATH_STYLE=1
S3_SET_ACL=0
```

本地访问时 SSH 隧道必须同时转发 `3210` 和 `9000`：

```bash
ssh -L 3210:127.0.0.1:3210 -L 9000:127.0.0.1:9000 <server-alias>
```

检查 RustFS：

```bash
curl -I http://127.0.0.1:9000/health
docker compose logs --tail=200 lobe-rustfs
docker compose logs --tail=200 lobe-rustfs-init
```

## 模型不可用

检查 `.env` 是否填了对应供应商 key：

```text
OPENAI_API_KEY
ANTHROPIC_API_KEY
GOOGLE_API_KEY
DEEPSEEK_API_KEY
OPENROUTER_API_KEY
```

如果使用兼容网关，配置对应 provider 的 proxy URL，例如：

```env
OPENAI_PROXY_URL=https://api.example.com/v1
```

修改 `.env` 后重启：

```bash
cd /opt/lobehub
docker compose up -d --force-recreate lobehub
```

如果启用了可选 NAT 代理，确认 LobeHub 容器继承了代理变量：

```bash
cd /opt/lobehub
docker exec lobehub env | grep -E '^(HTTP_PROXY|HTTPS_PROXY|NO_PROXY)='
curl -x http://127.0.0.1:7890 -I --max-time 10 https://api.deepseek.com
```

未启用 NAT 时，`HTTP_PROXY` 和 `HTTPS_PROXY` 应保持为空。

## xui/NAT 可选组件不可用

这两个组件不会随 `fresh` 自动安装。先检查 `.env`：

```text
ENABLE_XUI=true
ENABLE_NAT_PROXY=true
```

再按需运行：

```bash
sudo bash deploy.sh xui --yes
sudo bash deploy.sh nat-proxy --yes
```

NAT 依赖 SSH key 已经存在于服务器：

```bash
test -f "$NAT_SSH_KEY_PATH"
systemctl status nat-socks
systemctl status privoxy
```

## 端口误开放公网

验证脚本会失败：

```bash
sudo bash deploy.sh verify
```

这些端口不能监听 `0.0.0.0` 或 `[::]`：

```text
3210
9000
9001
15432
16379
18080
```

检查 compose 是否仍使用：

```yaml
127.0.0.1:3210
127.0.0.1:9000
```
