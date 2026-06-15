# 已知问题处理

## Open WebUI 没有注册入口

检查：

```bash
docker run --rm --network ai-platform_ai-net curlimages/curl:8.10.1 \
  -sS http://open-webui:8080/api/config | jq '.features.enable_signup'
```

如果返回 `false`，确认 Compose 中存在：

```yaml
ENABLE_PERSISTENT_CONFIG: "False"
ENABLE_SIGNUP: ${OPENWEBUI_ENABLE_SIGNUP:-true}
DEFAULT_USER_ROLE: ${OPENWEBUI_DEFAULT_USER_ROLE:-pending}
```

然后重建：

```bash
cd /opt/Serve
docker compose up -d --force-recreate open-webui
```

## 登录后 401 Unauthorized

确认：

```text
.env 存在 WEBUI_SECRET_KEY
docker-compose.yml 注入 WEBUI_SECRET_KEY: ${WEBUI_SECRET_KEY}
```

重建 Open WebUI 后清理浏览器中 `chat.example.com` 的站点数据。

## Docker 容器访问 172.18.0.1:7890 超时

确认：

```bash
systemctl status ai-proxy-firewall --no-pager
iptables -S INPUT | grep 7890
```

当前应有类似：

```text
-A INPUT -s 172.18.0.0/16 -d 172.18.0.1/32 -i br-* -p tcp --dport 7890 -j ACCEPT
```

修复：

```bash
sudo bash deploy.sh proxy
```

## API 域名被 Cloudflare Access 拦截

症状：

```bash
curl -I https://api.example.com/v1/models
```

返回 `302`，响应头里出现：

```text
Www-Authenticate: Cloudflare-Access
Location: https://<team>.cloudflareaccess.com/...
```

原因：`api.example.com` 被放进了 Cloudflare Access Application。OpenAI SDK 和脚本调用通常只带 `Authorization: Bearer ...`，不会有浏览器登录 cookie，因此会被 Access 层拦截。

修复：

```text
admin.example.com -> newapi:3000，加 Cloudflare Access
api.example.com   -> newapi:3000，不加 Cloudflare Access
```

然后用 NewAPI token 自身的额度、分组、IP 白名单以及 Cloudflare WAF/rate limit 保护 API 域名。

## 7890 公网监听

这是高风险状态。`verify.sh` 会直接失败。Privoxy 应只包含：

```text
listen-address 172.18.0.1:7890
forward-socks5t / 127.0.0.1:10808 .
```

不能出现：

```text
listen-address 0.0.0.0:7890
```

