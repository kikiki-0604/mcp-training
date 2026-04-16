#!/bin/sh
# sqlite-mcp コンテナの役割: DB初期化のみ
# 実際の MCP サーバーは mcpo コンテナが uvx で起動する

DB_PATH="/workspace/db/training.db"
INIT_SQL="/workspace/db/init-db.sql"

# DB ファイルが存在しない場合のみ初期化を実行
if [ ! -f "$DB_PATH" ]; then
  echo "[entrypoint] training.db が見つかりません。init-db.sql から初期化します..."

  if [ ! -f "$INIT_SQL" ]; then
    echo "[entrypoint] エラー: $INIT_SQL が見つかりません" >&2
    exit 1
  fi

  sqlite3 "$DB_PATH" < "$INIT_SQL"

  if [ $? -eq 0 ]; then
    echo "[entrypoint] DB 初期化が完了しました: $DB_PATH"
  else
    echo "[entrypoint] エラー: DB 初期化に失敗しました" >&2
    exit 1
  fi
else
  echo "[entrypoint] 既存の training.db を使用します: $DB_PATH"
fi

# DB初期化完了後はコンテナを待機状態で維持（healthcheck用）
echo "[entrypoint] DB 準備完了。待機中..."
tail -f /dev/null
