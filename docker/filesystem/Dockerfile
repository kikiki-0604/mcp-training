# ファイルシステム操作 MCP サーバー
# workspace/ 配下のファイル読み書きを MCP プロトコルで提供する
FROM node:20-alpine

WORKDIR /app

# MCP filesystem サーバーをグローバルインストール
RUN npm install -g @modelcontextprotocol/server-filesystem

# /workspace をマウントポイントとして起動
# このコンテナは参照・動作確認用（実際の MCP 接続は mcpo 経由）
CMD ["mcp-server-filesystem", "/workspace"]
