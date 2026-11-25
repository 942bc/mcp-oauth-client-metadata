#!/usr/bin/env bash
#
# 部署 MCP OAuth Client ID Metadata Document (CIMD) 到 GitHub Pages
#
# 用法：
#   ./deploy.sh                # 仓库名默认 mcp-oauth-client-metadata
#   REPO_NAME=xxx ./deploy.sh  # 自定义仓库名
#
set -euo pipefail

REPO_NAME="${REPO_NAME:-mcp-oauth-client-metadata}"
BRANCH="main"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ---------- 依赖检查 ----------
for c in git gh curl python3; do
  command -v "$c" >/dev/null 2>&1 || { echo "错误: 缺少依赖 $c" >&2; exit 1; }
done

if ! gh auth status >/dev/null 2>&1; then
  echo "错误: gh 未登录，请先执行 gh auth login" >&2
  exit 1
fi

OWNER="$(gh api user --jq .login)"
PAGES_URL="https://${OWNER}.github.io/${REPO_NAME}/oauth-client-metadata.json"

echo "==> GitHub 账号 : ${OWNER}"
echo "==> 仓库名      : ${REPO_NAME}"
echo "==> 文档地址    : ${PAGES_URL}"
echo

# ---------- 同步 client_id 到最终 URL ----------
echo "==> 同步 oauth-client-metadata.json 中的 client_id"
python3 - "$PAGES_URL" <<'PY'
import json, sys
path = "oauth-client-metadata.json"
with open(path, encoding="utf-8") as f:
    doc = json.load(f)
doc["client_id"] = sys.argv[1]
with open(path, "w", encoding="utf-8") as f:
    json.dump(doc, f, ensure_ascii=False, indent=2)
    f.write("\n")
print("    client_id ->", doc["client_id"])
PY
echo

# ---------- 初始化 git 仓库 ----------
if [ ! -d .git ]; then
  echo "==> git init"
  git init -b "$BRANCH" >/dev/null
fi
git add -A

if git diff --cached --quiet; then
  echo "==> 无新改动，跳过 commit"
else
  echo "==> git commit"
  git commit -m "chore: add MCP OAuth client metadata document" >/dev/null
fi
echo

# ---------- 创建/推送仓库 ----------
if gh repo view "${OWNER}/${REPO_NAME}" >/dev/null 2>&1; then
  echo "==> 仓库已存在，直接推送"
  if ! git remote get-url origin >/dev/null 2>&1; then
    git remote add origin "git@github.com:${OWNER}/${REPO_NAME}.git"
  fi
  git push -u origin "$BRANCH"
else
  echo "==> 创建公开仓库并推送"
  gh repo create "$REPO_NAME" --public --source=. --remote=origin --push
fi
echo

# ---------- 启用 GitHub Pages ----------
echo "==> 检查/启用 GitHub Pages"
if gh api "repos/${OWNER}/${REPO_NAME}/pages" >/dev/null 2>&1; then
  echo "    Pages 已启用"
else
  gh api -X POST "repos/${OWNER}/${REPO_NAME}/pages" \
    -H "Accept: application/vnd.github+json" \
    -f "source[branch]=${BRANCH}" \
    -f "source[path]=/" >/dev/null
  echo "    Pages 已启用 (${BRANCH} / 根目录)"
fi
echo

# ---------- 等待构建并验证 ----------
echo "==> 等待 Pages 构建（最多约 3 分钟）"
for i in $(seq 1 36); do
  code="$(curl -s -o /dev/null -w '%{http_code}' -m 15 "$PAGES_URL" || true)"
  if [ "$code" = "200" ]; then
    ct="$(curl -sI -m 15 "$PAGES_URL" | tr -d '\r' | awk -F': ' 'tolower($1)=="content-type"{print $2}')"
    echo
    echo "==> 部署完成"
    echo "    URL          : $PAGES_URL"
    echo "    HTTP         : 200"
    echo "    Content-Type : ${ct:-未返回}"
    echo "    ---- 文档内容 ----"
    curl -s -m 15 "$PAGES_URL"
    echo
    exit 0
  fi
  printf "    第 %d 次检查: HTTP %s，5 秒后重试...\n" "$i" "${code:-000}"
  sleep 5
done

echo "==> 超时：Pages 尚未就绪，请稍后手动检查"
echo "    gh api repos/${OWNER}/${REPO_NAME}/pages/builds/latest"
echo "    curl -i $PAGES_URL"
exit 1
