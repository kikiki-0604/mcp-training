# 01. システム全体構成

> 最終更新: 2026-03-01  作成者: インフラチーム

---

## 1. プロダクト概要

**サービス名**: ExampleShop（仮称）  
**概要**: 家電・ガジェット専門のB2C ECサイト  
**運用開始**: 2025年9月  
**月間アクティブユーザー**: 約2,000名（2026年3月時点）  
**月間受注件数**: 約500件

---

## 2. システム全体アーキテクチャ

```
[ユーザー]
    │
    ▼
[CDN: CloudFront]
    │
    ├── [静的アセット: S3]
    │
    ▼
[Application Load Balancer]
    │
    ├── /api/*  ──→ [APIサーバー (ECS Fargate x2)]
    │
    └── /*      ──→ [Webサーバー (ECS Fargate x2)]
                          │
                          ├── [RDS MySQL 8.0 (Primary)]
                          │       └── [RDS MySQL (Read Replica)]
                          │
                          ├── [ElastiCache Redis 7.0]
                          │
                          └── [外部API]
                                  ├── Stripe (決済)
                                  ├── ヤマト運輸API (配送)
                                  ├── 佐川急便API (配送)
                                  └── SendGrid (メール)
```

> **※ 研修環境について**  
> 本研修環境はDocker Composeで再現した簡易版です。  
> MySQL → SQLite、Redis → なし（キャッシュ無効）に置き換えています。

---

## 3. 技術スタック

### バックエンド

| 項目 | 内容 |
|------|------|
| 言語 | TypeScript 5.x |
| フレームワーク | Node.js 20 + Fastify 4.x |
| ORM | Prisma 5.x |
| DB（本番） | MySQL 8.0 (RDS) |
| DB（研修） | SQLite 3.x |
| キャッシュ | Redis 7.0 (ElastiCache) |
| 認証 | JWT (RS256) + Refresh Token |

### フロントエンド

| 項目 | 内容 |
|------|------|
| フレームワーク | Next.js 14 (App Router) |
| スタイリング | Tailwind CSS 3.x |
| 状態管理 | Zustand |
| API通信 | TanStack Query v5 |

### インフラ

| 項目 | 内容 |
|------|------|
| クラウド | AWS (ap-northeast-1) |
| コンテナ | ECS Fargate |
| CI/CD | GitHub Actions |
| IaC | Terraform 1.6 |
| 監視 | CloudWatch + Datadog |
| ログ | CloudWatch Logs → S3 (90日保存) |

---

## 4. 環境構成

| 環境 | 用途 | DB |
|------|------|----|
| production | 本番 | RDS MySQL (Multi-AZ) |
| staging | 受け入れテスト | RDS MySQL (Single-AZ) |
| development | 開発者ローカル | Docker MySQL |
| training | 研修用 | Docker SQLite |

---

## 5. 非機能要件

| 項目 | 目標値 |
|------|--------|
| 可用性 | 99.9% / 月 |
| API レスポンスタイム | p95 < 200ms |
| 決済処理タイムアウト | 30秒 |
| 同時接続数 | 最大500 |

---

## 6. セキュリティ設計

- 通信: HTTPS 強制（HSTS設定済み）
- 認証: JWT (有効期限15分) + Refresh Token (7日)
- パスワード: bcrypt (cost=12)
- SQLインジェクション対策: Prisma ORM使用（プリペアドステートメント）
- カード情報: 自社保持なし（Stripeトークン化）
- アクセスログ: 全APIリクエストを CloudWatch Logs に記録

---

## 7. 監視・アラート設定

| アラート | 閾値 | 通知先 |
|---------|------|--------|
| API エラー率 | > 5% / 5分 | Slack #ops-alert |
| 決済失敗連続 | 3件以上 | Slack #ops-alert + PagerDuty |
| DB CPU | > 80% / 5分 | PagerDuty |
| 在庫差異 | 任意 | Slack #ops-alert |

---

## 8. TODO / 既知の問題

- [ ] **[P1]** Read Replicaへの読み取りクエリ振り分け未実装（全クエリがPrimaryに集中）
- [ ] **[P2]** 検索機能がLIKE検索のため全文検索エンジン（Elasticsearch）導入検討中
- [ ] **[P2]** 画像アップロード機能未実装（商品画像はすべてexternal URL）
- [ ] **[P3]** レート制限（Rate Limiting）がAPIゲートウェイ未設定
- [ ] **[P3]** スロークエリの自動アラート未整備（手動確認のみ）
