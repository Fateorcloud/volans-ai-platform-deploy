# Volans LobeHub 自部署工具

[English](README.en.md) | 简体中文

这是一个面向个人或小团队的 LobeHub 自部署模板。它把当前默认栈收窄为
`LobeHub + PostgreSQL/PGVector + Redis + RustFS/S3 + SearXNG`，第一阶段只做
服务器本机访问测试，不默认发布公网域名。

旧的 NewAPI、Open WebUI、GPT Image Playground、Caddy 图站不再属于当前项目。
这套旧链路已经备份在 GitHub 分支 `codex/legacy-ai-stack-backup`，需要复用时从该
分支恢复。xui 和 NAT 出站代理被保留为独立可选网络组件，但不属于 LobeHub AI 平台
核心栈，默认部署不会安装。

## 架构

```text
Browser over SSH tunnel
  -> 127.0.0.1:3210  LobeHub
  -> 127.0.0.1:9000  RustFS S3 API, for uploads

LobeHub
  -> 127.0.0.1:15432 PostgreSQL / PGVector
  -> 127.0.0.1:16379 Redis
  -> 127.0.0.1:9000  RustFS
  -> 127.0.0.1:18080 SearXNG
  -> provider APIs configured in .env

Optional network components
  -> xui side stack, installed only by deploy.sh xui
  -> NAT egress proxy, installed only by deploy.sh nat-proxy
```

LobeHub 容器使用 host network，是为了让 `S3_ENDPOINT=http://127.0.0.1:9000`
同时对 LobeHub 服务端和通过 SSH 隧道访问的浏览器可达。其他持久化服务只映射到
`127.0.0.1`。

## 适合场景

- 你想先替换复杂 AI 平台，保留一个现代、可持久化的前端。
- 你暂时只给自己使用，通过 SSH 隧道访问，不先开放公网。
- 你希望接入 OpenAI、Anthropic、Google/Gemini、DeepSeek、OpenRouter 等供应商。
- 你希望将来能把 `/opt/lobehub`、`.env` 和备份复制到另一台服务器恢复。

不适合：需要商业计费、复杂团队权限、API 网关计量或工作流应用平台的场景。那些需求
应另行选 LibreChat、LiteLLM 或 Dify。xui/NAT 只作为独立网络层保留，不参与 AI 平台
的模型管理。

## 快速部署

在一台新的 Ubuntu 22.04/24.04 VPS 上：

```bash
git clone https://github.com/<your-name>/volans-ai-platform-deploy.git
cd volans-ai-platform-deploy
cp .env.example .env
nano .env
sudo bash deploy.sh fresh --yes
```

至少替换这些值：

```text
KEY_VAULTS_SECRET
AUTH_SECRET
POSTGRES_PASSWORD
RUSTFS_ACCESS_KEY
RUSTFS_SECRET_KEY
SEARXNG_SECRET
```

生成示例：

```bash
# KEY_VAULTS_SECRET and AUTH_SECRET
openssl rand -base64 32

# POSTGRES_PASSWORD, RUSTFS_SECRET_KEY, and SEARXNG_SECRET can use hex
openssl rand -hex 32
```

模型供应商 key 按需填写，未使用的保留为空：

```text
OPENAI_API_KEY
ANTHROPIC_API_KEY
GOOGLE_API_KEY
DEEPSEEK_API_KEY
OPENROUTER_API_KEY
```

## 本机访问

部署完成后，在本地电脑建立 SSH 隧道：

```bash
ssh -L 3210:127.0.0.1:3210 -L 9000:127.0.0.1:9000 <server-alias>
```

打开：

```text
http://127.0.0.1:3210
```

如果要检查 RustFS：

```text
http://127.0.0.1:9001
```

## 运维命令

```bash
sudo bash deploy.sh verify
sudo bash deploy.sh backup
sudo bash deploy.sh repair --yes
```

可选网络组件需要显式执行：

```bash
sudo bash deploy.sh xui --yes
sudo bash deploy.sh nat-proxy --yes
sudo bash deploy.sh network --yes
```

`fresh` 和 `repair` 不会自动安装 xui/NAT。

服务目录：

```text
/opt/lobehub
```

常用检查：

```bash
cd /opt/lobehub
docker compose ps
docker compose logs -f lobehub
docker compose logs -f lobe-rustfs
```

## 备份与迁移

手动备份：

```bash
sudo bash deploy.sh backup
```

备份文件默认写入：

```text
/opt/lobehub/backup/postgres_lobechat_YYYY-MM-DD_HHMMSS.sql.gz
/opt/lobehub/backup/rustfs_data_YYYY-MM-DD_HHMMSS.tar.gz
```

迁移到另一台服务器时，复制：

```text
/opt/lobehub/.env
PostgreSQL 备份
RustFS 备份
```

不要把这些文件提交到 Git。

## 公网发布

本模板第一阶段不发布公网。后续如果要挂 `chat.example.com`：

1. 先确认 LobeHub 登录/认证策略。
2. 给 LobeHub 反代 `127.0.0.1:3210`。
3. 给 S3/RustFS 配置浏览器可访问且受控的 endpoint。
4. 再把 `.env` 中的 `APP_URL` 和 `S3_ENDPOINT` 改成正式 URL。

## 更多文档

- [部署流程](docs/deployment.md)
- [运维手册](docs/operations.md)
- [可选 xui/NAT 网络组件](docs/network-components.md)
- [排障](docs/troubleshooting.md)
- [迁移与裁剪](docs/migration-and-trim.md)
- [开源发布检查](docs/open-source-release.md)

## 开源前检查

```bash
bash deploy.sh security-scan
git status --short
```

不要提交真实 `.env`、API key、服务器 IP、SSH key、数据库目录、RustFS 日志或备份包。
