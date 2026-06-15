#!/bin/sh
set -eu

HTML_DIR="${GPT_IMAGE_HTML_DIR:-/usr/share/nginx/html}"
INDEX_HTML="${HTML_DIR}/index.html"
AUTOFILL_JS="${HTML_DIR}/volans-autofill.js"

js_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

API_KEY_ESCAPED="$(js_escape "${IMAGE_SHARED_API_KEY:-}")"
API_URL_ESCAPED="$(js_escape "${DEFAULT_API_URL:-https://image.example.com/api-proxy}")"

cat > "$AUTOFILL_JS" <<EOF
(function () {
  var apiKey = "${API_KEY_ESCAPED}";
  var apiUrl = "${API_URL_ESCAPED}";

  function setStartupQuery() {
    if (!apiKey) return;
    try {
      var url = new URL(window.location.href);
      var changed = false;

      if (url.searchParams.get("apiKey") !== apiKey) {
        url.searchParams.set("apiKey", apiKey);
        changed = true;
      }

      if (apiUrl && url.searchParams.get("apiUrl") !== apiUrl) {
        url.searchParams.set("apiUrl", apiUrl);
        changed = true;
      }

      if (changed) {
        window.history.replaceState(null, "", url.toString());
      }
    } catch (error) {
      console.warn("[volans] API key autofill skipped", error);
    }
  }

  function isApiKeyInput(input) {
    var placeholder = (input.getAttribute("placeholder") || "").toLowerCase();
    var name = (input.getAttribute("name") || "").toLowerCase();
    var autocomplete = (input.getAttribute("autocomplete") || "").toLowerCase();
    var parent = input.closest("label, section, form, div");
    var label = parent ? (parent.textContent || "").toLowerCase() : "";

    return placeholder === "sk-..." ||
      placeholder === "fal_key" ||
      name.indexOf("apikey") !== -1 ||
      autocomplete.indexOf("api") !== -1 ||
      label.indexOf("api key") !== -1;
  }

  function hideButton(button) {
    button.setAttribute("aria-hidden", "true");
    button.setAttribute("tabindex", "-1");
    button.disabled = true;
    button.style.display = "none";
  }

  function lockInput(input) {
    input.type = "password";
    input.readOnly = true;
    input.setAttribute("autocomplete", "off");
    input.setAttribute("data-volans-api-key-locked", "true");
    input.style.webkitTextSecurity = "disc";

    var wrapper = input.closest(".relative") || input.parentElement;
    if (wrapper) {
      Array.prototype.forEach.call(wrapper.querySelectorAll("button"), hideButton);
    }
  }

  function hideApiKey() {
    Array.prototype.forEach.call(document.querySelectorAll("input"), function (input) {
      if (isApiKeyInput(input)) {
        lockInput(input);
      }
    });
  }

  setStartupQuery();

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", hideApiKey, { once: true });
  } else {
    hideApiKey();
  }

  new MutationObserver(hideApiKey).observe(document.documentElement, {
    childList: true,
    subtree: true
  });
})();
EOF

if [ ! -f "$INDEX_HTML" ]; then
  echo "[volans] index.html not found at $INDEX_HTML; autofill script generated only"
  exit 0
fi

if ! grep -q 'volans-autofill.js' "$INDEX_HTML"; then
  sed -i 's#<script type="module"#<script src="./volans-autofill.js"></script>\
    <script type="module"#' "$INDEX_HTML"
fi

if [ -z "${IMAGE_SHARED_API_KEY:-}" ]; then
  echo "[volans] IMAGE_SHARED_API_KEY is empty; API key autofill will stay disabled"
fi
