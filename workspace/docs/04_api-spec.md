# 04. API仕様書

> 最終更新: 2026-03-01  作成者: バックエンドチーム  
> Base URL: `https://api.example-shop.co.jp/api/v1`（本番）  
> 研修環境: `http://localhost:4000/api/v1`（未起動・参照用）

---

## 1. 共通仕様

### 認証

```
Authorization: Bearer <JWT token>
```

- JWT有効期限: 15分
- Refresh Token: `/api/v1/auth/refresh` で更新（有効期限7日）
- 認証不要エンドポイント: 商品一覧・詳細・検索

### レスポンス形式

**成功レスポンス**:
```json
{
  "data": { ... },
  "meta": { "total": 100, "page": 1, "per_page": 20 }
}
```

**エラーレスポンス**:
```json
{
  "error": {
    "code": "INSUFFICIENT_STOCK",
    "message": "在庫が不足しています",
    "details": { "product_id": 1, "available": 0 }
  }
}
```

### ページネーション

クエリパラメータ: `?page=1&per_page=20`（デフォルト: per_page=20, 最大100）

---

## 2. 認証API

### POST /auth/register（ユーザー登録）

**リクエスト**:
```json
{
  "email": "tanaka.taro@example.com",
  "password": "SecurePass123!",
  "name": "田中 太郎",
  "phone": "090-1111-0001"
}
```

**レスポンス** `201 Created`:
```json
{
  "data": {
    "user_id": 1,
    "email": "tanaka.taro@example.com",
    "name": "田中 太郎",
    "access_token": "eyJhbGciOiJSUzI1NiJ9...",
    "refresh_token": "rt_abc123..."
  }
}
```

---

### POST /auth/login（ログイン）

**リクエスト**:
```json
{
  "email": "tanaka.taro@example.com",
  "password": "SecurePass123!"
}
```

**レスポンス** `200 OK`:
```json
{
  "data": {
    "access_token": "eyJhbGciOiJSUzI1NiJ9...",
    "refresh_token": "rt_abc123...",
    "expires_in": 900
  }
}
```

---

## 3. 商品API

### GET /products（商品一覧）

**クエリパラメータ**:
| パラメータ | 型 | 説明 |
|------------|-----|------|
| category | string | カテゴリスラッグ |
| sort | string | popular / new / price_asc / price_desc |
| min_price | integer | 最低価格（税抜） |
| max_price | integer | 最高価格（税抜） |
| q | string | キーワード検索（名前・説明） |

**レスポンス** `200 OK`:
```json
{
  "data": [
    {
      "id": 1,
      "sku": "SP-A15-BLK",
      "name": "スマートフォン TypeA15 ブラック",
      "price": 89800,
      "tax_rate": 0.10,
      "price_with_tax": 98780,
      "stock_count": 50,
      "is_active": true,
      "category": { "id": 2, "name": "スマートフォン・タブレット" },
      "average_rating": 5.0,
      "review_count": 1
    }
  ],
  "meta": { "total": 20, "page": 1, "per_page": 20 }
}
```

---

### GET /products/{id}（商品詳細）

**レスポンス** `200 OK`:
```json
{
  "data": {
    "id": 1,
    "sku": "SP-A15-BLK",
    "name": "スマートフォン TypeA15 ブラック",
    "description": "最新フラグシップモデル。6.7インチ有機EL",
    "price": 89800,
    "tax_rate": 0.10,
    "price_with_tax": 98780,
    "stock_count": 50,
    "category": { "id": 2, "name": "スマートフォン・タブレット" },
    "reviews": [
      {
        "id": 1,
        "user_name": "田中 太郎",
        "rating": 5,
        "title": "最高のスマホ",
        "body": "カメラ性能が素晴らしい。",
        "created_at": "2026-02-16T10:00:00+09:00"
      }
    ],
    "average_rating": 5.0
  }
}
```

---

## 4. カートAPI

### POST /cart/add（カート追加）

**リクエスト** `要認証`:
```json
{
  "product_id": 1,
  "quantity": 1
}
```

**レスポンス** `200 OK`:
```json
{
  "data": {
    "cart_items": [
      {
        "product_id": 1,
        "name": "スマートフォン TypeA15 ブラック",
        "quantity": 1,
        "unit_price": 89800,
        "unit_price_with_tax": 98780
      }
    ],
    "subtotal": 89800,
    "total_with_tax": 98780
  }
}
```

**エラー**:
- `409 Conflict`: 在庫不足 `INSUFFICIENT_STOCK`
- `404 Not Found`: 商品が存在しない/無効 `PRODUCT_NOT_FOUND`

---

## 5. 注文API

### POST /orders（注文確定）

**リクエスト** `要認証`:
```json
{
  "coupon_code": "SPRING500",
  "payment_method": "credit_card",
  "shipping_address": {
    "postal_code": "100-0001",
    "address": "東京都千代田区千代田1-1",
    "name": "田中 太郎",
    "phone": "090-1111-0001"
  }
}
```

**レスポンス** `201 Created`:
```json
{
  "data": {
    "order_id": 21,
    "status": "pending",
    "subtotal": 89800,
    "tax_amount": 8980,
    "shipping_fee": 0,
    "discount_amount": 500,
    "total_amount": 98280,
    "items": [
      {
        "product_id": 1,
        "name": "スマートフォン TypeA15 ブラック",
        "quantity": 1,
        "unit_price": 89800
      }
    ],
    "created_at": "2026-03-11T10:00:00+09:00"
  }
}
```

**エラー**:
- `409 Conflict`: 在庫不足 `INSUFFICIENT_STOCK`
- `422 Unprocessable`: クーポン無効 `INVALID_COUPON`
- `422 Unprocessable`: カートが空 `EMPTY_CART`

---

### GET /orders（注文履歴）

**クエリパラメータ** `要認証`:
| パラメータ | 型 | 説明 |
|------------|-----|------|
| status | string | ステータスフィルター |
| from | date | 開始日 (YYYY-MM-DD) |
| to | date | 終了日 (YYYY-MM-DD) |

**レスポンス** `200 OK`:
```json
{
  "data": [
    {
      "id": 1,
      "status": "delivered",
      "total_amount": 98780,
      "item_count": 1,
      "created_at": "2026-02-10T10:15:00+09:00"
    }
  ],
  "meta": { "total": 2, "page": 1, "per_page": 20 }
}
```

---

## 6. 決済API

### POST /payments（決済実行）

**リクエスト** `要認証`:
```json
{
  "order_id": 21,
  "method": "credit_card",
  "stripe_payment_method_id": "pm_abc123"
}
```

**レスポンス** `200 OK`（成功）:
```json
{
  "data": {
    "payment_id": 21,
    "status": "completed",
    "amount": 98280,
    "transaction_id": "TXN-20260311-021",
    "paid_at": "2026-03-11T10:00:05+09:00"
  }
}
```

**レスポンス** `200 OK`（3Dセキュア認証必要）:
```json
{
  "data": {
    "payment_id": 21,
    "status": "requires_action",
    "action_type": "redirect_to_url",
    "redirect_url": "https://hooks.stripe.com/3d_secure/..."
  }
}
```

**エラー**:
- `402 Payment Required`: カード拒否 `CARD_DECLINED`
- `408 Request Timeout`: 決済タイムアウト（リトライ後）`PAYMENT_TIMEOUT`
- `503 Service Unavailable`: 決済ゲートウェイ障害 `GATEWAY_ERROR`

---

## 7. レビューAPI

### POST /reviews（レビュー投稿）

**リクエスト** `要認証`:
```json
{
  "product_id": 1,
  "rating": 5,
  "title": "最高のスマホ",
  "body": "カメラ性能が素晴らしい。"
}
```

> **TODO**: 購入済み確認バリデーション未実装。

---

## 8. 管理者API

> 管理者APIは別途 `Authorization: Bearer <admin-JWT>` が必要。  
> 詳細ドキュメント: Notion「管理者API仕様」参照（社内限定）

### GET /admin/dashboard（売上サマリー）

**レスポンス例**:
```json
{
  "data": {
    "today_sales": 97780,
    "today_orders": 2,
    "pending_shipments": 3,
    "low_stock_products": [
      { "product_id": 11, "name": "4K有機ELテレビ 55インチ", "stock": 14 }
    ]
  }
}
```

---

## 9. Webhookエンドポイント

### POST /webhooks/delivery（配送完了コールバック）

**ヘッダー**:
```
X-Delivery-Signature: sha256=<HMAC-SHA256署名>
X-Carrier: yamato
```

**リクエスト本文（ヤマト）**:
```json
{
  "tracking_number": "YM-4455667788",
  "status": "delivered",
  "delivered_at": "2026-03-06T10:00:30+09:00"
}
```

---

## 10. エラーコード一覧

| コード | HTTP | 説明 |
|--------|------|------|
| INSUFFICIENT_STOCK | 409 | 在庫不足 |
| PRODUCT_NOT_FOUND | 404 | 商品が存在しない |
| INVALID_COUPON | 422 | クーポンが無効/期限切れ |
| EMPTY_CART | 422 | カートが空 |
| CARD_DECLINED | 402 | カード拒否 |
| CARD_EXPIRED | 402 | カード期限切れ |
| PAYMENT_TIMEOUT | 408 | 決済タイムアウト |
| GATEWAY_ERROR | 503 | 決済ゲートウェイ障害 |
| UNAUTHORIZED | 401 | 認証エラー |
| FORBIDDEN | 403 | 権限不足 |
| VALIDATION_ERROR | 422 | バリデーションエラー |
| INTERNAL_ERROR | 500 | サーバー内部エラー |
