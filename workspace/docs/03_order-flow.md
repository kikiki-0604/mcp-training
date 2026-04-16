# 03. 注文〜決済〜発送フロー仕様

> 最終更新: 2026-02-28  作成者: バックエンドチーム

---

## 1. 全体フロー概要

```
[ユーザー]
    │
    ▼
①  カート追加 (POST /api/v1/cart/add)
    │
    ▼
②  注文確定 (POST /api/v1/orders)
    │  ├── 在庫引当（同期）
    │  ├── 注文レコード作成 (status=pending)
    │  └── 注文確認メール送信
    │
    ▼
③  決済処理 (POST /api/v1/payments)
    │  ├── [成功] status: pending → paid
    │  │         発送準備通知（倉庫システム）
    │  └── [失敗] status: pending → cancelled
    │              在庫戻し
    │              決済失敗通知メール
    │
    ▼
④  出荷処理（倉庫オペレーター手動 + API）
    │  └── status: paid → shipped
    │        発送通知メール
    │
    ▼
⑤  配達完了（配送業者APIコールバック）
       └── status: shipped → delivered
             配達完了通知メール
```

---

## 2. 各ステップ詳細

### 2.1 カート追加

**エンドポイント**: `POST /api/v1/cart/add`

処理内容:
1. 商品の `is_active = 1` を確認
2. `stock_count > 0` を確認（在庫ゼロは追加不可）
3. Redisにカート情報を保存（TTL: 7日）

> **TODO**: カートに追加した時点で在庫を「仮引き当て」する機能未実装。  
> 同一商品を複数ユーザーがカート追加→同時注文した場合、在庫がマイナスになる可能性あり。

---

### 2.2 注文確定

**エンドポイント**: `POST /api/v1/orders`

処理内容（トランザクション内で実行）:

```
BEGIN TRANSACTION;
  1. カート内容取得（Redis）
  2. 在庫チェック（SELECT ... FOR UPDATE）
  3. 在庫引当（products.stock_count -= quantity）
  4. stock_history レコード作成（change_type='sale'）
  5. orders レコード作成（status='pending'）
  6. order_items レコード作成（unit_price=注文時点の価格）
  7. coupons.used_count += 1（クーポン使用時）
COMMIT;
  8. 注文確認メール送信（非同期・SendGrid）
```

**エラー処理**:
| エラー | HTTP | 処理 |
|--------|------|------|
| 在庫不足 | 409 | ロールバック・エラーレスポンス |
| 商品無効 | 422 | ロールバック・エラーレスポンス |
| クーポン無効/期限切れ | 422 | ロールバック・エラーレスポンス |
| DBエラー | 500 | ロールバック・アラート通知 |

---

### 2.3 決済処理

**エンドポイント**: `POST /api/v1/payments`

#### クレジットカード（Stripe）

```
POST /api/v1/payments
  ↓
Stripe API: PaymentIntent.create()
  ├── [success] transaction_id 取得 → status='completed', paid_at 更新
  ├── [timeout 30s] リトライ（最大2回）
  │     ├── [成功] 同上
  │     └── [失敗] status='failed', error_code 記録
  └── [card_declined] status='failed', error_code='CARD_DECLINED'
```

**3Dセキュア（SCA対応）**:
- 10万円以上の注文は自動で3Dセキュア認証フローへ
- 認証完了まで `status='pending'` を維持
- 認証タイムアウト（24時間）でキャンセル

> **既知の問題**: 3Dセキュア認証URLの有効期限が短く（15分）、ユーザーが気づかずにセッション切れになるケースが報告されている。  
> 対応予定: 2026-04-15リリース

#### コンビニ払い

- 支払い番号をメール送知し `status='pending'` を維持
- 入金確認バッチ（毎日9:00〜）で `status='completed'` に更新
- 支払い期限: 注文から3日

#### 銀行振込

- 振込口座情報をメール送知
- 入金確認バッチで更新
- 支払い期限: 注文から7日

#### PayPay

- PayPay API: `POST /v2/payments/requestPaymentForWebSSO`
- リダイレクト後にコールバックで確認

---

### 2.4 出荷処理

倉庫管理システム（WMS）との連携:

```
倉庫スタッフ → WMS画面で出荷登録
  ↓
WMS → POST /api/v1/shipments/{id}/ship
  ├── tracking_number 登録
  ├── shipped_at 更新
  ├── orders.status: paid → shipped
  └── 発送通知メール送信
```

**対応配送業者**:
| 業者 | コード | API |
|------|--------|-----|
| ヤマト運輸 | yamato | B2クラウド API |
| 佐川急便 | sagawa | e-飛伝II API |
| 日本郵便 | jppost | ゆうパックAPI |

> **TODO**: 日本郵便のAPIは未連携（現在は手動で追跡番号を登録）。

---

### 2.5 配達完了

配送業者からのWebhookコールバック:

```
配送業者API → POST /api/v1/webhooks/delivery
  ├── 認証: HMAC-SHA256 署名検証
  ├── tracking_number から shipment 特定
  ├── delivered_at 更新
  ├── orders.status: shipped → delivered
  └── 配達完了通知メール
```

---

## 3. 返品・返金フロー

> **TODO**: 返品フロー未実装。現在は管理画面から手動で対応。  
> 実装予定: 2026-05 マイルストーン

暫定運用:
1. ユーザーからメール/問い合わせフォームで返品申請
2. カスタマーサポートが管理画面でステータスを `refunded` に変更
3. Stripe ダッシュボードから手動返金

---

## 4. エラーハンドリング方針

### 冪等性（Idempotency）

決済APIは `Idempotency-Key` ヘッダーをサポート:
- クライアントが同一キーで再送した場合、同じレスポンスを返す
- キーはRedisに24時間保存

### 在庫整合性チェック

注文確定時の二重引き当て防止:
- `SELECT ... FOR UPDATE` で行ロック取得（MySQL本番環境）
- SQLiteの研修環境ではトランザクション分離で対応

### メール送信失敗

- SendGrid APIエラー時はSQSキューに積んでリトライ
- 最大3回リトライ後はエラーログに記録（送信失敗は注文処理に影響しない）

> **TODO**: SQSリトライ基盤が未設定の環境あり。Stagingではメール送信失敗が握りつぶされている。
