# 02. DB設計書

> 最終更新: 2026-02-20  作成者: バックエンドチーム

---

## 1. 概要

本システムのデータベースは MySQL 8.0 (本番) / SQLite 3 (研修) で構成される。  
文字コードは `utf8mb4`、照合順序は `utf8mb4_unicode_ci`。

---

## 2. ER図（テキスト表現）

```
categories ─┐
             │ 1:N
           products ─────────────── order_items ─── orders ─── users
             │                           │               │
             │                           │               ├── payments
             │                           │               ├── shipments
             └── reviews ────────────────┘               └── coupons
                   │
                   └── users

stock_history ──── products
stock_history ──── orders (optional)
```

---

## 3. テーブル定義

### 3.1 categories（カテゴリ）

| カラム | 型 | 制約 | 説明 |
|--------|-----|------|------|
| id | INTEGER | PK, AUTO | カテゴリID |
| name | TEXT | NOT NULL, UNIQUE | カテゴリ名 |
| slug | TEXT | NOT NULL, UNIQUE | URLスラッグ |
| description | TEXT | NULL可 | 説明文 |
| parent_id | INTEGER | FK→categories.id | 親カテゴリ（未使用） |
| sort_order | INTEGER | NOT NULL, DEFAULT 0 | 表示順 |
| created_at | TEXT | NOT NULL | 作成日時 |

> **TODO**: 親子カテゴリ（parent_id）の表示UI未実装。現在は1階層のみ運用。

---

### 3.2 users（ユーザー）

| カラム | 型 | 制約 | 説明 |
|--------|-----|------|------|
| id | INTEGER | PK, AUTO | ユーザーID |
| email | TEXT | NOT NULL, UNIQUE | メールアドレス |
| name | TEXT | NOT NULL | 氏名 |
| phone | TEXT | NULL可 | 電話番号 |
| postal_code | TEXT | NULL可 | 郵便番号 |
| address | TEXT | NULL可 | 住所 |
| is_active | INTEGER | NOT NULL, DEFAULT 1 | 有効フラグ |
| created_at | TEXT | NOT NULL | 登録日時 |
| updated_at | TEXT | NOT NULL | 更新日時 |

> **注意**: パスワードハッシュはusersテーブルに持たず、認証サービス（別DB）で管理。  
> **TODO**: 複数配送先（shipping_addresses テーブル）未実装。現在は1ユーザー1住所。

---

### 3.3 products（商品）

| カラム | 型 | 制約 | 説明 |
|--------|-----|------|------|
| id | INTEGER | PK, AUTO | 商品ID |
| category_id | INTEGER | NOT NULL, FK→categories.id | カテゴリID |
| sku | TEXT | NOT NULL, UNIQUE | 商品コード |
| name | TEXT | NOT NULL | 商品名 |
| description | TEXT | NULL可 | 説明文 |
| price | INTEGER | NOT NULL | 単価（税抜・円） |
| tax_rate | REAL | NOT NULL, DEFAULT 0.10 | 消費税率 |
| stock_count | INTEGER | NOT NULL, DEFAULT 0 | 現在在庫数 |
| is_active | INTEGER | NOT NULL, DEFAULT 1 | 販売フラグ |
| created_at | TEXT | NOT NULL | 作成日時 |
| updated_at | TEXT | NOT NULL | 更新日時 |

> **注意**: `stock_count` は `stock_history` の集計値と必ず一致させること。  
> 不整合が起きた場合は `stock_history` を正とする。（3/8に実際に発生した事例あり）

---

### 3.4 orders（注文）

| カラム | 型 | 制約 | 説明 |
|--------|-----|------|------|
| id | INTEGER | PK, AUTO | 注文ID |
| user_id | INTEGER | NOT NULL, FK→users.id | ユーザーID |
| status | TEXT | NOT NULL, DEFAULT 'pending' | 注文ステータス |
| subtotal | INTEGER | NOT NULL | 税抜小計（円） |
| tax_amount | INTEGER | NOT NULL | 消費税額（円） |
| shipping_fee | INTEGER | NOT NULL, DEFAULT 0 | 送料（円） |
| total_amount | INTEGER | NOT NULL | 合計（税込・円） |
| coupon_id | INTEGER | FK→coupons.id | 使用クーポン |
| discount_amount | INTEGER | NOT NULL, DEFAULT 0 | 割引額（円） |
| note | TEXT | NULL可 | 備考 |
| created_at | TEXT | NOT NULL | 注文日時 |
| updated_at | TEXT | NOT NULL | 更新日時 |

**注文ステータス遷移**:
```
pending → confirmed → paid → shipped → delivered
                    ↘ cancelled
                      ↘ refunded
```

---

### 3.5 order_items（注文明細）

| カラム | 型 | 制約 | 説明 |
|--------|-----|------|------|
| id | INTEGER | PK, AUTO | 明細ID |
| order_id | INTEGER | NOT NULL, FK→orders.id | 注文ID |
| product_id | INTEGER | NOT NULL, FK→products.id | 商品ID |
| quantity | INTEGER | NOT NULL | 数量 |
| unit_price | INTEGER | NOT NULL | 注文時点の単価（税抜） |
| tax_rate | REAL | NOT NULL | 注文時点の税率 |
| created_at | TEXT | NOT NULL | 作成日時 |

> **設計注意**: `unit_price` は注文時点の価格を保存（商品マスタの価格変更に影響されない）。

---

### 3.6 payments（決済）

| カラム | 型 | 制約 | 説明 |
|--------|-----|------|------|
| id | INTEGER | PK, AUTO | 決済ID |
| order_id | INTEGER | NOT NULL, FK→orders.id | 注文ID |
| method | TEXT | NOT NULL | 決済方法 |
| status | TEXT | NOT NULL, DEFAULT 'pending' | 決済ステータス |
| amount | INTEGER | NOT NULL | 決済金額（円） |
| transaction_id | TEXT | UNIQUE（NULL許可） | 外部トランザクションID |
| error_code | TEXT | NULL可 | エラーコード |
| error_message | TEXT | NULL可 | エラーメッセージ |
| paid_at | TEXT | NULL可 | 決済完了日時 |
| created_at | TEXT | NOT NULL | 作成日時 |
| updated_at | TEXT | NOT NULL | 更新日時 |

**決済方法**: `credit_card` / `convenience` / `bank_transfer` / `paypay`

---

### 3.7 shipments（配送）

| カラム | 型 | 制約 | 説明 |
|--------|-----|------|------|
| id | INTEGER | PK, AUTO | 配送ID |
| order_id | INTEGER | NOT NULL, FK→orders.id | 注文ID |
| carrier | TEXT | NOT NULL, DEFAULT 'yamato' | 配送業者 |
| tracking_number | TEXT | NULL可 | 追跡番号 |
| status | TEXT | NOT NULL, DEFAULT 'preparing' | 配送ステータス |
| shipped_at | TEXT | NULL可 | 出荷日時 |
| delivered_at | TEXT | NULL可 | 配達完了日時 |
| created_at | TEXT | NOT NULL | 作成日時 |
| updated_at | TEXT | NOT NULL | 更新日時 |

---

### 3.8 reviews（レビュー）

| カラム | 型 | 制約 | 説明 |
|--------|-----|------|------|
| id | INTEGER | PK, AUTO | レビューID |
| product_id | INTEGER | NOT NULL, FK→products.id | 商品ID |
| user_id | INTEGER | NOT NULL, FK→users.id | ユーザーID |
| rating | INTEGER | NOT NULL, CHECK(1-5) | 評価（1〜5） |
| title | TEXT | NULL可 | タイトル |
| body | TEXT | NULL可 | 本文 |
| is_visible | INTEGER | NOT NULL, DEFAULT 1 | 表示フラグ |
| created_at | TEXT | NOT NULL | 投稿日時 |

**ユニーク制約**: (product_id, user_id) → 1ユーザー1商品1レビュー

> **TODO**: 購入済み確認チェック未実装（未購入ユーザーもレビュー投稿可能な状態）。

---

### 3.9 coupons（クーポン）

| カラム | 型 | 制約 | 説明 |
|--------|-----|------|------|
| id | INTEGER | PK, AUTO | クーポンID |
| code | TEXT | NOT NULL, UNIQUE | クーポンコード |
| discount_type | TEXT | NOT NULL | 割引種別（fixed/percent） |
| discount_value | INTEGER | NOT NULL | 割引値（円 or %） |
| min_order_amount | INTEGER | NULL可 | 最低注文金額 |
| max_uses | INTEGER | NULL可 | 最大利用回数 |
| used_count | INTEGER | NOT NULL, DEFAULT 0 | 使用回数 |
| expires_at | TEXT | NULL可 | 有効期限 |
| is_active | INTEGER | NOT NULL, DEFAULT 1 | 有効フラグ |
| created_at | TEXT | NOT NULL | 作成日時 |

---

### 3.10 stock_history（在庫履歴）

| カラム | 型 | 制約 | 説明 |
|--------|-----|------|------|
| id | INTEGER | PK, AUTO | 履歴ID |
| product_id | INTEGER | NOT NULL, FK→products.id | 商品ID |
| change_type | TEXT | NOT NULL | 変動種別 |
| quantity | INTEGER | NOT NULL | 変動数量（負=減少） |
| stock_after | INTEGER | NOT NULL | 変動後在庫数 |
| order_id | INTEGER | FK→orders.id | 関連注文ID |
| reason | TEXT | NULL可 | 理由 |
| created_at | TEXT | NOT NULL | 記録日時 |

**change_type**: `purchase`（仕入）/ `sale`（販売）/ `adjustment`（調整）/ `return`（返品）/ `expired`（廃棄）

---

## 4. インデックス設計

主なインデックス（パフォーマンス観点）:

| テーブル | インデックス | 目的 |
|---------|------------|------|
| users | idx_users_email | メール検索・認証 |
| products | idx_products_category | カテゴリ別一覧 |
| products | idx_products_sku | 商品コード検索 |
| orders | idx_orders_user | ユーザー別注文履歴 |
| orders | idx_orders_status | ステータス別集計 |
| orders | idx_orders_created | 日時範囲検索 |
| payments | idx_payments_status | 決済状態管理 |
| stock_history | idx_stock_history_product | 商品別在庫履歴 |

> **TODO**: `orders.created_at` と `status` の複合インデックスが未設定。月次集計クエリが遅い。

---

## 5. 設計上の注意点

1. **在庫整合性**: `products.stock_count` と `stock_history` の集計が一致することを前提にしているが、  
   アプリケーション側の実装漏れにより3/8に不整合が発生した（詳細は障害報告書参照）。

2. **注文金額の丸め**: 消費税の計算は `FLOOR(subtotal * tax_rate)` で切り捨て。端数処理を注文時に確定させ `tax_amount` に保存する。

3. **外部キー制約**: SQLiteでは `PRAGMA foreign_keys = ON;` が必要。接続のたびに設定すること。

4. **ソフトデリート**: 現在は `is_active` フラグで論理削除のみ実装。物理削除は不可とする。
