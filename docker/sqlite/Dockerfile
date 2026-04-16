# SQLite 操作 MCP サーバー + DB 自動初期化
# 起動時に training.db が存在しなければ init-db.sql から初期化する
FROM node:20-alpine

# sqlite3 CLI（DB 初期化に使用）
RUN apk add --no-cache sqlite

WORKDIR /app

# MCP sqlite サーバーをグローバルインストール
RUN npm install -g @modelcontextprotocol/server-sqlite

# 初期化スクリプトをコピーして実行権限を付与
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
