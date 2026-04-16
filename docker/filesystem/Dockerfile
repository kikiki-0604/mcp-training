# ファイルシステム操作 MCP サーバー
# workspace/ 配下のファイル読み書きを MCP プロトコルで提供する
FROM node:20-alpine

WORKDIR /app

# MCP filesystem サーバーをグローバルインストール
RUN npm install -g @modelcontextprotocol/server-filesystem

# 実際の MCP 接続は mcpo コンテナが npx で起動するため
# このコンテナは参照用として待機状態を維持する
CMD ["tail", "-f", "/dev/null"]
