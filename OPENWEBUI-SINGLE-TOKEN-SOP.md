# Open WebUI Single Token SOP

This SOP is for the production stack on the Hong Kong server at `/opt/Serve`.
The server configuration is the source of truth; local files are templates and records.

## 1. Architecture Choice

Current choice: **Plan A: one Open WebUI instance + one global NewAPI token**.

Why:

- Open WebUI user groups do not directly bind upstream API tokens.
- A root user's personal token is not inherited by other user groups.
- Group permissions control UI/resource access, not provider credential routing.
- This is a small-circle platform, so operational simplicity is more important than strict per-group billing for now.

Future upgrade paths:

| Option | When to use |
|---|---|
| Plan B: multiple Open WebUI instances | Need strict basic/vip/svip token separation without custom code |
| Plan C: token broker | Need one chat entrypoint plus true per-user/per-group token routing |

## 2. Account Approval Flow

Goal: users can register at `chat.example.com`, but cannot use the platform until approved.

Compose settings for `open-webui`:

```yaml
ENABLE_SIGNUP: "true"
DEFAULT_USER_ROLE: pending
ENABLE_DIRECT_CONNECTIONS: "false"
ENABLE_API_KEYS: "false"
USER_PERMISSIONS_FEATURES_API_KEYS: "false"
BYPASS_MODEL_ACCESS_CONTROL: "false"
```

After changing Compose on the server:

```bash
cd /opt/Serve
docker compose config --quiet
docker compose up -d --force-recreate open-webui
docker compose exec open-webui sh -c 'env | sort | grep -E "ENABLE_SIGNUP|DEFAULT_USER_ROLE|ENABLE_DIRECT_CONNECTIONS|ENABLE_API_KEYS|USER_PERMISSIONS_FEATURES_API_KEYS|BYPASS_MODEL_ACCESS_CONTROL"'
```

Open WebUI may persist settings in its database. After restart, also confirm the same values in the admin UI.

## 3. User Groups

Suggested groups:

| Open WebUI group | Purpose | Notes |
|---|---|---|
| `basic` | Approved normal users | Start here |
| `vip` | Trusted users | Allow higher-cost chat if the UI supports clean visibility control |
| `svip` | High-reasoning / image users | Add cautiously |
| `admin` | Admin/testing | Only administrators |

Important:

- A group does not provide a NewAPI token.
- If a user is still `pending`, adding the user to a group may not be enough.
- Approve the user by changing the user's role to `user`, then assign the group.

## 4. Recommended Group Permissions

Use low default permissions and add only what is needed.

For `basic`:

```text
Access model list: on
Access knowledge: off at first
Access prompts: on
Import prompts: off
Export prompts: off
Access tools: off
Access functions/skills: off
Share model: off
Public model share: off
Share knowledge: off
Share prompts: off at first
Share tools: off
```

For `vip`:

```text
Same as basic
Optionally enable access knowledge and share prompts
Do not enable tools/functions unless you have tested them
```

For `svip`:

```text
Same as vip
Optionally enable image workflow access
Do not enable public sharing by default
```

For `admin`:

```text
Full admin permissions
Do not use admin as a normal chat account
```

## 5. Global NewAPI Token

Open WebUI uses one global NewAPI token:

```text
Base URL: http://newapi:3000/v1
API Key:  ${NEWAPI_MASTER_KEY}
```

The token lives in `.env` and is injected into Open WebUI:

```yaml
OPENAI_API_BASE_URL: http://newapi:3000/v1
OPENAI_API_KEY: ${NEWAPI_MASTER_KEY}
```

Users should never see this token.

## 6. Model Visibility

If the current Open WebUI build supports reliable per-model access control:

1. Create curated Workspace Model entries.
2. Make high-cost models private/restricted.
3. Grant access only to trusted groups.

If it does not work reliably:

1. Do not promise strict model separation.
2. Keep the model list small.
3. Hide or remove high-cost models from general use.
4. Allow only trusted users into the platform.

## 7. Image Generation

Image generation can use either:

- The same global NewAPI token for simplicity.
- A separate image token if you want easier log filtering and emergency revocation.

Open WebUI image settings:

```text
Image generation: enabled
Prompt generation: disabled at first
Engine: OpenAI
Base URL: http://newapi:3000/v1
API Key: sk-[REDACTED_IMAGE_OR_GLOBAL_TOKEN]
Model: gpt-image-2
```

Validation:

```bash
cd /opt/Serve
docker compose logs --tail=100 newapi | grep -E '/v1/images/generations|gpt-image'
```

Expected request path:

```text
POST /v1/images/generations
```

If the log shows `/v1/chat/completions`, the model is still being used as a chat model.

## 8. New User Checklist

1. User registers at `chat.example.com`.
2. Admin changes role from `pending` to `user`.
3. Admin assigns group: `basic`, `vip`, or `svip`.
4. User signs out and signs back in.
5. Admin watches Open WebUI and NewAPI logs during first call.

Logs:

```bash
cd /opt/Serve
docker compose logs -f --tail=200 open-webui
docker compose logs -f --tail=100 newapi
```

## 9. Security Checks

Run on the server:

```bash
ss -lntup | grep -E '7890|9090'
```

Expected:

```text
172.18.0.1:7890
127.0.0.1:9090
```

Not expected:

```text
0.0.0.0:7890
*:7890
```

Container proxy smoke test:

```bash
docker run --rm --network ai-platform_ai-net \
  curlimages/curl:8.10.1 \
  -x http://172.18.0.1:7890 \
  -I --max-time 10 http://www.gstatic.com/generate_204
```

Expected: `HTTP/1.1 204 No Content`.
