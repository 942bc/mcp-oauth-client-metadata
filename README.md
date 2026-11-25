# mcp-oauth-client-metadata

托管 MCP OAuth 的 **Client ID Metadata Document (CIMD)**，供 Stargate（Logto）在 OAuth 授权流程中拉取。

- 文档地址：<https://942bc.github.io/mcp-oauth-client-metadata/oauth-client-metadata.json>
- 对应 MCP 资源：<https://stargate.yingmi.com/mcp/v2/oauth/qieman>
- 授权服务器元数据：`client_id_metadata_document_supported: true`

## 部署

仓库名必须与文档地址一致（`mcp-oauth-client-metadata`），否则要同步修改 `oauth-client-metadata.json` 里的 `client_id`。

```bash
cd mcp-oauth-client-metadata-page
git init -b main
git add -A
git commit -m "chore: add MCP oauth client metadata document"
gh repo create mcp-oauth-client-metadata --public --source=. --remote=origin --push
gh api -X POST repos/942bc/mcp-oauth-client-metadata/pages \
  -f 'source[branch]=main' -f 'source[path]=/'
```

等待 Pages 构建完成后验证：

```bash
curl -s -i https://942bc.github.io/mcp-oauth-client-metadata/oauth-client-metadata.json
# 期望：HTTP 200, content-type: application/json
```

## 注意

1. `client_id` 字段必须**严格等于**文档自身的 URL（含协议、域名、路径、无 query/fragment）。
2. `redirect_uris` 必须与 OAuth 客户端发起授权时用的回调地址逐字一致（当前为 `http://localhost:8020/ai-platform/mcp-oauth-callback`）。
3. `token_endpoint_auth_method` 固定为 `none`（CIMD 客户端不持有 client_secret）。
4. GitHub Pages 对 `.json` 返回 `application/json`，`.nojekyll` 用于关闭 Jekyll 处理。
