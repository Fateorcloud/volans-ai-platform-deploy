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
