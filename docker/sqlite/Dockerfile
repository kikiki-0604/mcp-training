# SQLite 操作 MCP サーバー + DB 自動初期化
# mcp-server-sqlite は Python 製のため python:3.11-slim をベースにする
FROM python:3.11-slim

# sqlite3 CLI（DB 初期化に使用）
RUN apt-get update && apt-get install -y sqlite3 && rm -rf /var/lib/apt/lists/*

# uv（Python パッケージランナー）をインストール
# uvx mcp-server-sqlite でサーバーを起動する
RUN pip install uv

# 初期化スクリプトをコピーして実行権限を付与
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
