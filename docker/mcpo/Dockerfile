# mcpo（MCP→HTTP プロキシ）に Node.js と MCP サーバーパッケージを追加
FROM ghcr.io/open-webui/mcpo:main

# Node.js 20.x のインストール
RUN apt-get update && apt-get install -y curl gnupg && \
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# MCP サーバーパッケージをグローバルインストール
RUN npm install -g \
    @modelcontextprotocol/server-filesystem \
    @modelcontextprotocol/server-sqlite

# mcpo のエントリポイントはベースイメージに定義済み
# config.json は docker-compose で /app/config.json にマウント
CMD ["mcpo", "--host", "0.0.0.0", "--port", "8000", "--config", "/app/config.json"]
