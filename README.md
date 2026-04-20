# MCP研修環境

エンジニア向けAI活用研修用のDocker環境です。  
**Docker Desktop とブラウザだけで動作します。**

Gemini APIの無料枠を使い、Open WebUI経由でファイルシステムとSQLiteデータベースをMCPツールとして操作する演習環境です。

> **この資料の対象者**: エンジニア1年目の方でも理解できるよう、Docker・Git・MCPの基礎知識から丁寧に説明しています。

---

## 目次

1. [このプロジェクトで学べること](#1-このプロジェクトで学べること)
2. [基礎知識：Dockerとコンテナとは](#2-基礎知識dockerとコンテナとは)
3. [基礎知識：Gitとは](#3-基礎知識gitとは)
4. [基礎知識：MCPサーバーとは](#4-基礎知識mcpサーバーとは)
5. [このシステムのアーキテクチャ](#5-このシステムのアーキテクチャ)
6. [セットアップ手順](#6-セットアップ手順)
7. [演習シナリオ](#7-演習シナリオ)
8. [DBリセット手順](#8-dbリセット手順)
9. [トラブルシューティング](#9-トラブルシューティング)
10. [停止・削除](#10-停止削除)

---

## 1. このプロジェクトで学べること

| 学習テーマ | 内容 |
|-----------|------|
| AIへの指示の出し方（プロンプト） | 曖昧な質問と明確な質問の違いを体験する |
| MCPツールによるAIの「手」の拡張 | AIがファイルやDBを実際に操作するのを確認する |
| ログ分析・DB照会の自動化 | 10日分のログ横断分析や売上集計をAIに任せる |
| 仕様書とDBの整合性チェック | ドキュメントとコードのずれをAIが検出する |

---

## 2. 基礎知識：Dockerとコンテナとは

### コンテナとは何か

プログラムを動かすためには、OS・ライブラリ・設定など**たくさんの「環境」が必要**です。  
「自分のPCでは動くのに、別のPCでは動かない」という問題がよく起きます。

**コンテナ**は、アプリケーションとその動作に必要な環境（ライブラリ・設定など）を**まとめて箱に詰めた**ものです。  
箱ごと渡せば、どのPCでも同じように動きます。

```
【コンテナのイメージ】

  あなたのPC
  ┌─────────────────────────────┐
  │  Docker（コンテナの管理ソフト）  │
  │                               │
  │  ┌───────────┐  ┌─────────┐ │
  │  │ コンテナA   │  │コンテナB │ │
  │  │ Node.js環境 │  │Python環境│ │
  │  │ アプリAが動く│  │アプリBが動│ │
  │  └───────────┘  └─────────┘ │
  └─────────────────────────────┘
```

### Dockerとは

**Docker** はコンテナを作成・起動・管理するためのソフトウェアです。  
`docker-compose.yml` というファイルに「どんなコンテナをどう起動するか」を書いておけば、コマンド1つで複数のコンテナをまとめて起動できます。

### よく使うDockerコマンド

```bash
# コンテナをビルドして起動（-d はバックグラウンド実行）
docker compose up -d --build

# 起動中のコンテナ一覧を確認
docker compose ps

# ログを確認する
docker compose logs コンテナ名

# コンテナを停止する
docker compose down
```

### このプロジェクトで起動するコンテナ

| コンテナ名 | 役割 |
|-----------|------|
| `mcp-training-webui` | ブラウザで使うチャット画面（Open WebUI） |
| `mcp-training-mcpo` | MCPサーバーをHTTPで使えるようにする変換器 |
| `mcp-training-filesystem` | ファイル操作を担当するMCPサーバー |
| `mcp-training-sqlite` | DB初期化を担当するコンテナ |

---

## 3. 基礎知識：Gitとは

### Gitとは何か

**Git** はソースコードの「変更履歴」を管理するツールです。  
「いつ・誰が・何を・なぜ変更したか」を記録しておくことで、以前の状態に戻したり、複数人で同じコードを編集したりできます。

### 基本的な概念

| 用語 | 意味 |
|------|------|
| **リポジトリ（repo）** | コードと変更履歴をまとめて保存する場所 |
| **クローン（clone）** | リモートのリポジトリを自分のPCにコピーすること |
| **コミット（commit）** | 変更内容をひとまとめにして記録すること |
| **ブランチ（branch）** | 本流（main）から分岐した作業用の流れ |
| **プッシュ（push）** | 自分のPCの変更をリモートに送ること |

### よく使うGitコマンド

```bash
# リポジトリをクローン（コピー）する
git clone <URL>

# 変更状況を確認する
git status

# 変更履歴を確認する
git log --oneline
```

> **この研修での使い方**: 研修環境のコードをクローンして手元にコピーし、`docker compose` で起動するだけです。Gitの詳細な操作は今回は不要です。

---

## 4. 基礎知識：MCPサーバーとは

### AIは「考えるだけ」では限界がある

ChatGPTやGeminiなどのAIは、テキストを読んで回答を生成することは得意です。  
しかし、そのままでは**ファイルを読んだり、データベースを検索したりすることはできません**。

### MCPとは

**MCP（Model Context Protocol）** は、AIが外部のツールやデータにアクセスするための「共通のルール（プロトコル）」です。  
Anthropic社が2024年に公開しました。

MCPを使うと、AIは次のような操作ができるようになります：

- ファイルシステムの読み書き
- データベースへのSQLクエリ実行
- Webの検索・取得
- カレンダーやメールの操作　など

### MCPサーバーとMCPクライアント

| 役割 | 説明 | この研修での担当 |
|------|------|----------------|
| **MCPクライアント** | AIがツールを呼び出す側 | Open WebUI + Gemini API |
| **MCPサーバー** | 実際にファイルやDBを操作する側 | filesystem-mcp / sqlite-mcp |

```
【MCPのイメージ】

ユーザー → AI（Gemini） → MCPサーバー → ファイル・DB
          「このフォルダの  「わかった。      「読み込みました」
           ファイル一覧を    filesystem-mcpに
           教えて」          聞いてみる」
```

### mcpoとは

MCPサーバーはそのままではHTTPで通信できないため、**mcpo**（MCP to OpenAPI プロキシ）がMCPサーバーをHTTP APIに変換します。  
これにより、Open WebUI（ブラウザ側）からMCPサーバーを呼び出せるようになります。

```
Open WebUI  →（HTTP）→  mcpo  →（MCP）→  filesystem-mcp
                                     →（MCP）→  sqlite-mcp
```

---

## 5. このシステムのアーキテクチャ

```
ブラウザ
  │
  ▼
┌─────────────────────────────────┐
│  open-webui  :3000              │
│  （チャットUI + Gemini API接続）  │
└──────────────┬──────────────────┘
               │ HTTP（OpenAPI）
               ▼
┌─────────────────────────────────┐
│  mcpo  :8000                    │
│  （MCP → HTTP/OpenAPI プロキシ）  │
│                                 │
│  ┌──────────────────────────┐  │
│  │ filesystem-mcp            │  │  ← workspace/ を操作
│  │ （MCPサブプロセス）         │  │
│  └──────────────────────────┘  │
│  ┌──────────────────────────┐  │
│  │ sqlite-mcp                │  │  ← training.db を操作
│  │ （MCPサブプロセス）         │  │
│  └──────────────────────────┘  │
└─────────────────────────────────┘

┌─────────────────────────────────┐
│  sqlite-mcp コンテナ             │  ← DB自動初期化用
│  （起動時に init-db.sql を実行）  │
└─────────────────────────────────┘
```

### データフロー（1回の質問で起きること）

```
① ユーザーが Open WebUI でチャット入力
      ↓
② Gemini API がメッセージを解釈し、ツール呼び出しが必要か判断
      ↓
③ 必要なら mcpo 経由で filesystem / sqlite の MCPサーバーを呼び出す
      ↓
④ ファイルの読み込みや SQL 実行の結果が Gemini API に返る
      ↓
⑤ Gemini API が結果をもとに回答を生成し、Open WebUI に表示
```

---

## 6. セットアップ手順

### 前提条件

以下がインストール済みであることを確認してください。

- **Docker Desktop**
  - Mac / Windows: [https://www.docker.com/products/docker-desktop/](https://www.docker.com/products/docker-desktop/)
  - インストール後、Docker Desktop を起動しておくこと
- **Git**
  - Mac: ターミナルで `git --version` と入力して確認
  - Windows: [https://git-scm.com/](https://git-scm.com/) からインストール

---

### Step 1: Gemini APIキーの取得

Gemini APIは無料枠で利用できます。

1. ブラウザで [https://aistudio.google.com](https://aistudio.google.com) を開く
2. Googleアカウントでログイン
3. 左側メニューの **「Get API key」** をクリック
4. **「Create API key」** → プロジェクトを選択（またはデフォルト）
5. 表示されたAPIキーをコピーして安全な場所に保管

> **注意**: APIキーは他人に見せないこと。`.env` ファイルは `.gitignore` に含まれており、Gitにコミットされません。

---

### Step 2: リポジトリのクローン

ターミナル（Mac）またはPowerShell / Git Bash（Windows）を開いて実行します。

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

> **補足**: `git clone` でリモートのコードが手元のPCにコピーされます。`cd mcp-training` でそのフォルダに移動します。

---

### Step 3: 環境変数ファイルの設定

`.env.example` を `.env` にコピーして、APIキーを設定します。

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

次に `.env` ファイルをテキストエディタで開き、APIキーを書き換えます：

```bash
# Mac/Linux（nanoエディタで開く場合）
nano .env

# 内容の例
GEMINI_API_KEY=your_gemini_api_key_here
              ↑ここを取得したAPIキーに書き換える
```

> **補足**: `.env` ファイルは「環境変数」を設定するファイルです。アプリが起動時に読み込み、APIキーなどの秘密情報をコードに直書きせずに渡す仕組みです。

---

### Step 4: Dockerコンテナの起動

```bash
docker compose up -d --build
```

| オプション | 意味 |
|-----------|------|
| `up` | コンテナを起動する |
| `-d` | バックグラウンドで実行する（ターミナルを占有しない） |
| `--build` | Dockerイメージをビルド（作成）してから起動する |

**初回起動時はイメージのビルドに数分かかります。**  
以下のメッセージが出れば起動完了です：

```
✔ Container mcp-training-sqlite      Started
✔ Container mcp-training-filesystem  Started
✔ Container mcp-training-mcpo        Started
✔ Container mcp-training-webui       Started
```

起動確認コマンド：

```bash
docker compose ps
```

全コンテナの `STATUS` が `Up` になっていれば正常です。

---

### Step 5: Open WebUIへのアクセスと初期設定

#### アカウント作成

1. ブラウザで [http://localhost:3000](http://localhost:3000) を開く
2. **「Get started」** をクリック
3. 適当なメールアドレスとパスワードでアカウント作成  
   （このアカウントはあなたのPC内だけで使われます。本物のメールアドレスでなくてもOKです）

#### Gemini APIキーの設定

1. ログイン後、右上のアイコン → **「Admin Panel」**
2. **「Settings」** → **「Connections」**
3. **Google Gemini API** の項目に、Step 1で取得したAPIキーを入力して保存

#### MCPツールの有効化

1. 右上アイコン → **「Settings」** → **「Tools」**
2. **「+」ボタン** をクリックして以下を2つ追加：

| ツール名 | URL |
|---------|-----|
| ファイルシステムツール | `http://mcpo:8000/filesystem` |
| SQLiteツール | `http://mcpo:8000/sqlite` |

> **補足**: URLの `mcpo` はコンテナ名です。同じDockerネットワーク内のコンテナ同士はコンテナ名でアクセスできます（`localhost` ではなく `mcpo` と書く理由です）。

---

### Step 6: 動作確認

チャット画面でツールアイコンが有効になっていることを確認してから、以下を入力してみましょう：

```
workspace/docs/ フォルダの中にあるファイルの一覧を教えてください。
```

ファイル一覧が返ってきたら設定完了です！

---

## 7. 演習シナリオ

詳細は `workspace/docs/training-scenarios.md` を参照してください。

### 演習一覧

| 演習 | 内容 | 使用ツール |
|------|------|-----------|
| 演習1: ログ分析 | 10日分のログを横断分析して障害報告書を生成 | filesystem |
| 演習2: DB操作 | 自然言語でSQLなしにDBへ問い合わせ | sqlite |
| 演習3: ドキュメント連携 | 仕様書とDBを照合して未実装・不整合を洗い出す | filesystem + sqlite |
| 演習4: プロンプト改善 | チーム対抗でプロンプトの質を競う | filesystem + sqlite |

### 良いプロンプトの5要素

AIへの質問（プロンプト）は書き方で回答の質が大きく変わります。

| 要素 | 書き方の例 | 役割 |
|------|----------|------|
| ① 役割 | 「あなたはSREエンジニアです」 | AIに専門家の視点を持たせる |
| ② 背景 | 「3月に障害が多発しており」 | AIが文脈を理解して回答できるようにする |
| ③ 依頼 | 「ログを分析してください」 | 何をしてほしいかを明確にする |
| ④ 制約 | 「ERRORレベルのみ対象、WARNは除く」 | 回答の範囲・条件を絞る |
| ⑤ 出力形式 | 「表形式で、件数・時間帯・原因の仮説を列挙」 | 使いやすい形式で受け取る |

**ポイント**: 5要素をすべて入れる必要はありません。  
「役割＋依頼＋出力形式」の3つを意識するだけで大幅に改善します。

---

## 8. DBリセット手順

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

## 9. トラブルシューティング

| 症状 | 原因 | 対処法 |
|------|------|--------|
| `http://localhost:3000` にアクセスできない | コンテナが起動していない | `docker compose ps` で状態確認。`docker compose up -d` を再実行 |
| Gemini APIが応答しない | APIキーが間違っている | Open WebUI の Connections 設定でAPIキーを確認・再入力 |
| ツール（filesystem/sqlite）が使えない | mcpoが起動していない、またはツール未登録 | `docker compose logs mcpo` でエラー確認。Tools設定でURLを再登録 |
| DBが空 / テーブルが存在しない | init-db.sql が実行されていない | `docker compose logs sqlite-mcp` を確認。[DBリセット手順](#8-dbリセット手順)を実施 |
| `docker compose up` でエラー | `.env` ファイルが存在しない | `cp .env.example .env` を実行してAPIキーを設定 |
| Windowsでパス関連エラー | 改行コードの問題（CRLF vs LF） | `git config core.autocrlf false` を設定してから再クローン |
| mcpoの起動が遅い | 初回は`npx`がパッケージをダウンロードする | 初回起動時は2〜3分かかる場合あり。しばらく待ってからアクセス |

### ログの確認方法

問題が起きたときはまずログを確認しましょう。

```bash
# 全サービスのログをまとめて確認
docker compose logs

# 特定サービスのログを確認
docker compose logs open-webui
docker compose logs mcpo
docker compose logs sqlite-mcp

# リアルタイムでログを監視（Ctrl+C で終了）
docker compose logs -f mcpo
```

### コンテナの状態確認

```bash
docker compose ps
```

`STATUS` 列が `Up` のものが正常に起動しているコンテナです。  
`Exit` や `Restarting` が表示されている場合は `docker compose logs <コンテナ名>` でエラー内容を確認してください。

---

## 10. 停止・削除

```bash
# コンテナを停止（データは保持）
docker compose down

# コンテナとボリュームを完全削除（Open WebUIのアカウント情報も削除）
docker compose down -v
```

> **補足**: `docker compose down` だけではDBファイルや `workspace/` 内のファイルは削除されません。`-v` オプションはDockerが管理するボリューム（Open WebUIのデータ）のみ削除します。
