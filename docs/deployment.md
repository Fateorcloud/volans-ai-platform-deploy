# 部署流程

## 1. 准备 `.env`

```bash
cp .env.example .env
nano .env
```

必须替换：

```text
KEY_VAULTS_SECRET
AUTH_SECRET
POSTGRES_PASSWORD
RUSTFS_ACCESS_KEY
RUSTFS_SECRET_KEY
SEARXNG_SECRET
```

生成方式：

```bash
openssl rand -hex 32
openssl rand -base64 32
```

按需填写模型供应商：

```text
OPENAI_API_KEY
ANTHROPIC_API_KEY
GOOGLE_API_KEY
DEEPSEEK_API_KEY
OPENROUTER_API_KEY
```

没有模型 key 时服务仍可启动，但不能真正发起模型调用。

## 2. Fresh 部署

```bash
sudo bash deploy.sh fresh --yes
```

脚本会执行：

```text
基础软件包、UFW、swap
Docker CE
渲染 /opt/lobehub
启动 LobeHub、PostgreSQL、Redis、RustFS、SearXNG
安装每日备份 cron
执行本机端口和服务健康检查
```

## 3. 本机访问

在本地电脑执行：

```bash
ssh -L 3210:127.0.0.1:3210 -L 9000:127.0.0.1:9000 <server-alias>
```

访问：

```text
http://127.0.0.1:3210
```

如果需要 RustFS 控制台，再加：

```bash
ssh -L 9001:127.0.0.1:9001 <server-alias>
```

访问：

```text
http://127.0.0.1:9001
```

## 4. 验证

```bash
sudo bash deploy.sh verify
```

重点确认：

```text
lobehub, lobe-postgres, lobe-redis, lobe-rustfs, lobe-searxng 已启动
3210, 9000, 9001, 15432, 16379, 18080 只监听 127.0.0.1
PostgreSQL / Redis / RustFS 健康检查通过
http://127.0.0.1:3210 返回 HTTP 响应
```

## 5. 后续公网发布

第一阶段不配置公网入口。准备发布时再做：

```text
chat.example.com -> reverse proxy -> 127.0.0.1:3210
s3.example.com   -> reverse proxy -> 127.0.0.1:9000
```

同时更新 `.env`：

```env
APP_URL=https://chat.example.com
S3_ENDPOINT=https://s3.example.com
```

不要在未配置认证和 S3 CORS/访问策略前开放公网。
