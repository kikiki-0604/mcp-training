#!/bin/sh
# SQLite MCP サーバーの起動前に DB を初期化するスクリプト

DB_PATH="/workspace/db/training.db"
INIT_SQL="/workspace/db/init-db.sql"

# DB ファイルが存在しない場合のみ初期化を実行
if [ ! -f "$DB_PATH" ]; then
  echo "[entrypoint] training.db が見つかりません。init-db.sql から初期化します..."

  if [ ! -f "$INIT_SQL" ]; then
    echo "[entrypoint] エラー: $INIT_SQL が見つかりません" >&2
    exit 1
  fi

  # sqlite3 CLI で DB を作成・初期化
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

# MCP SQLite サーバーを起動
exec mcp-server-sqlite --db-path "$DB_PATH"
