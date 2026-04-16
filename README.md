# MCP研修環境

エンジニア向けAI活用研修用のDocker環境です。  
**Docker Desktop とブラウザだけで動作します。**

Gemini APIの無料枠を使い、Open WebUI経由でファイルシステムとSQLiteデータベースをMCPツールとして操作する演習環境です。

---

## アーキテクチャ

```
ブラウザ
  │
  ▼
┌─────────────────────────────────┐
│  open-webui  :3000              │
│  (チャットUI + Gemini API接続)   │
└──────────────┬──────────────────┘
               │ HTTP (OpenAPI)
               ▼
┌─────────────────────────────────┐
│  mcpo  :8000                    │
│  (MCP → HTTP/OpenAPIプロキシ)    │
│                                 │
│  ┌─────────────────────────┐   │
│  │ filesystem-mcp           │   │  ← workspace/ を操作
│  │ (MCP サブプロセス)        │   │
│  └─────────────────────────┘   │
│  ┌─────────────────────────┐   │
│  │ sqlite-mcp               │   │  ← training.db を操作
│  │ (MCP サブプロセス)        │   │
│  └─────────────────────────┘   │
└─────────────────────────────────┘

┌─────────────────────────────────┐
│  sqlite-mcp コンテナ             │  ← DB自動初期化用
│  (起動時に init-db.sql を実行)   │
└─────────────────────────────────┘
```

**データフロー**:
1. ユーザーが Open WebUI でチャット
2. Gemini API がツール呼び出しを判断
3. mcpo が filesystem / sqlite の MCP サーバーを起動
4. ファイル読み込みや SQL 実行の結果を Gemini API に返す
5. 回答を Open WebUI に表示

---

## 受講者向けセットアップ手順

### 前提条件

- Docker Desktop がインストール済みであること
  - Mac: [https://www.docker.com/products/docker-desktop/](https://www.docker.com/products/docker-desktop/)
  - Windows: 同上（WSL2 バックエンド推奨）
- Git がインストール済みであること

---

### Step 1: Gemini APIキーの取得

1. ブラウザで [https://aistudio.google.com](https://aistudio.google.com) を開く
2. Googleアカウントでログイン
3. 左側メニューの **「Get API key」** をクリック
4. **「Create API key」** → プロジェクトを選択（またはデフォルト）
5. 表示されたAPIキーをコピーして安全な場所に保管

> **注意**: APIキーは他人に見せないこと。`.env` ファイルは `.gitignore` に含まれており、Gitにコミットされません。

---

### Step 2: リポジトリのクローン

**Mac / Linux**:
```bash
git clone <このリポジトリのURL>
cd mcp-training
```

**Windows（PowerShell or Git Bash）**:
```powershell
git clone <このリポジトリのURL>
cd mcp-training
```

---

### Step 3: 環境変数ファイルの設定

**Mac / Linux**:
```bash
cp .env.example .env
```

**Windows（PowerShell）**:
```powershell
Copy-Item .env.example .env
```

**Windows（Git Bash）**:
```bash
cp .env.example .env
```

次に `.env` ファイルを編集してAPIキーを設定します：

```bash
# Mac/Linux
nano .env
# または
open -e .env
```

```
GEMINI_API_KEY=your_gemini_api_key_here
              ↑ここを取得したAPIキーに書き換える
```

---

### Step 4: Docker コンテナの起動

```bash
docker compose up -d --build
```

初回起動時はイメージのビルドに数分かかります。  
以下のメッセージが出れば起動完了です：

```
✔ Container mcp-training-sqlite    Started
✔ Container mcp-training-filesystem  Started
✔ Container mcp-training-mcpo      Started
✔ Container mcp-training-webui     Started
```

---

### Step 5: Open WebUIへのアクセスと初期設定

1. ブラウザで [http://localhost:3000](http://localhost:3000) を開く
2. **「Get started」** をクリックし、適当なメールアドレスとパスワードでアカウント作成
   （このアカウントはローカルのみで使用されます）
3. ログイン後、右上のアイコン → **「Admin Panel」** → **「Settings」** → **「Connections」**
4. **Google Gemini API** の項目に取得したAPIキーを入力して保存

#### MCPツールの有効化

1. 右上アイコン → **「Settings」** → **「Tools」**
2. 「+」ボタンをクリックして以下を追加：
   - URL: `http://mcpo:8000/filesystem`（ファイルシステムツール）
   - URL: `http://mcpo:8000/sqlite`（SQLiteツール）

---

### Step 6: 動作確認

チャット画面でツールが有効になっていることを確認してから、以下を入力してみましょう：

```
workspace/docs/ フォルダの中にあるファイルの一覧を教えてください。
```

ファイル一覧が返ってきたら設定完了です！

---

## 演習シナリオ

詳細は `workspace/docs/training-scenarios.md` を参照してください。

| 演習 | 内容 | 使用ツール |
|------|------|-----------|
| 演習1: ログ分析 | 10日分のログを横断分析して障害報告書を生成 | filesystem |
| 演習2: DB操作 | 自然言語でSQLなしにDBへ問い合わせ | sqlite |
| 演習3: ドキュメント連携 | 仕様書とDBを照合して未実装・不整合を洗い出す | filesystem + sqlite |
| 演習4: プロンプト改善 | チーム対抗でプロンプトの質を競う | filesystem + sqlite |

---

## DBリセット手順

研修環境のデータベースを初期状態に戻す場合：

```bash
# コンテナを停止
docker compose down

# DBファイルを削除
rm workspace/db/training.db

# コンテナを再起動（init-db.sql から自動再初期化される）
docker compose up -d
```

---

## トラブルシューティング

| 症状 | 原因 | 対処法 |
|------|------|--------|
| `http://localhost:3000` にアクセスできない | コンテナが起動していない | `docker compose ps` で状態確認。`docker compose up -d` を再実行 |
| Gemini APIが応答しない | APIキーが間違っている | `.env` ファイルのキーを確認。Open WebUI の Connections 設定も確認 |
| ツール（filesystem/sqlite）が使えない | mcpoが起動していない | `docker compose logs mcpo` でエラーを確認 |
| DBが空 / テーブルが存在しない | init-db.sql が実行されていない | `docker compose logs sqlite-mcp` を確認。DBリセット手順を実施 |
| `docker compose up` でエラー | `.env` ファイルが存在しない | `cp .env.example .env` を実行してAPIキーを設定 |
| Windowsでパス関連エラー | 改行コードの問題 | `git config core.autocrlf false` を設定してから再クローン |
| mcpoの起動が遅い | node_modulesのキャッシュなし | 初回起動時は `npx` がパッケージをダウンロードするため2〜3分かかる場合あり |

### ログの確認方法

```bash
# 全サービスのログを確認
docker compose logs

# 特定サービスのログを確認
docker compose logs open-webui
docker compose logs mcpo
docker compose logs sqlite-mcp

# リアルタイムでログを監視
docker compose logs -f mcpo
```

### コンテナの状態確認

```bash
docker compose ps
```

---

## 停止・削除

```bash
# コンテナを停止（データは保持）
docker compose down

# コンテナとボリュームを完全削除（Open WebUIのデータも削除）
docker compose down -v
```
