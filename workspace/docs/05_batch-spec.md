# 05. バッチ処理仕様書

> 最終更新: 2026-02-25  作成者: バックエンドチーム

---

## 1. バッチ一覧

| バッチID | バッチ名 | スケジュール | 実行時間目安 |
|---------|---------|------------|------------|
| B-01 | 夜間メンテナンスバッチ | 毎日 00:05 | ~5分 |
| B-02 | 入金確認バッチ | 毎日 09:00, 12:00, 18:00 | ~1分 |
| B-03 | 配送状況同期バッチ | 毎時 :30 | ~2分 |
| B-04 | 定時在庫同期バッチ | 毎日 12:00 | ~3分 |
| B-05 | 督促メールバッチ | 毎日 08:00 | ~1分 |
| B-06 | 売上日次集計バッチ | 毎日 21:00 | ~3分 |
| B-07 | レコメンド更新バッチ | 毎日 18:00 | ~10分 |
| B-08 | 週次レコメンドモデル更新 | 毎週月曜 18:00 | ~30分 |
| B-09 | クーポン有効期限チェック | 毎日 00:30 | ~1分 |
| B-10 | 棚卸し差異チェックバッチ | 毎日 08:00 | ~5分 |

---

## 2. 各バッチ詳細仕様

### B-01: 夜間メンテナンスバッチ

**スケジュール**: 毎日 00:05 (JST)  
**処理内容**:
1. 在庫補充チェック（`stock_count < 10` の商品を抽出）
2. 購買担当へメール通知（補充対象あり時のみ）
3. 期限切れセッションの削除（Redisの自動TTLで対応済みのため現在はNOOP）

**ログ出力例**:
```
[batch] 夜間バッチ開始
[batch] 在庫補充対象商品: N件 (SKU1, SKU2, ...)
[batch] 夜間バッチ完了: 処理時間=Xs
```

**リカバリ手順**: 実行失敗時は手動で再実行可能。冪等性あり（複数回実行しても安全）。

---

### B-02: 入金確認バッチ

**スケジュール**: 毎日 09:00 / 12:00 / 18:00 (JST)  
**対象**: `payments.status = 'pending'` かつ `method IN ('convenience', 'bank_transfer')`  
**処理内容**:
1. 銀行API / コンビニ決済APIで入金確認
2. 入金確認できた注文: `payments.status → completed`, `orders.status → paid`
3. 入金確認メール送信
4. 支払い期限超過の注文（コンビニ3日、銀行7日）: `status → cancelled`, 在庫戻し

**エラー処理**: 外部APIタイムアウト時は次回バッチ実行時にリトライ。

> **TODO**: 銀行APIの本番接続設定が未完了。Staging環境でのみテスト済み。

---

### B-03: 配送状況同期バッチ

**スケジュール**: 毎時 :30  
**対象**: `shipments.status = 'shipped'` または `'in_transit'`  
**処理内容**:
1. ヤマト運輸 / 佐川急便 APIに追跡番号で問い合わせ
2. ステータス変化があれば `shipments.status` 更新
3. 配達完了（delivered）になったら `orders.status → delivered`, 通知メール送信

> **TODO**: 日本郵便のAPI連携未実装。ゆうパックの追跡は手動確認のみ。  
> **TODO**: API呼び出し失敗時の再試行ロジックがシンプルすぎる（単純リトライのみ）。

---

### B-04: 定時在庫同期バッチ

**スケジュール**: 毎日 12:00 (JST)  
**処理内容**:
1. `products.stock_count` と `stock_history` の集計値を照合
2. 差異があれば `WARN` ログ出力 + Slack通知
3. 差異が5個以上の場合は `ERROR` + PagerDutyアラート

**差異検出SQL**:
```sql
SELECT p.id, p.sku, p.stock_count AS system_count,
       COALESCE(SUM(sh.quantity), 0) AS history_sum
FROM products p
LEFT JOIN stock_history sh ON sh.product_id = p.id
GROUP BY p.id
HAVING p.stock_count != history_sum;
```

> **注意**: 3/8に在庫不整合が発生した事例あり（詳細はログ参照）。  
> 根本原因: 倉庫での誤カウント。3/9の実査で解消。

---

### B-05: 督促メールバッチ

**スケジュール**: 毎日 08:00 (JST)  
**対象**: `payments.status = 'pending'` かつ未払い日数が条件を満たすもの
| 決済方法 | 督促タイミング |
|---------|-------------|
| convenience | 注文翌日・2日後 |
| bank_transfer | 注文翌日・3日後・6日後 |

**処理内容**: 督促メール送信（SendGrid テンプレートID: `d-XXXXXXXX`）

---

### B-06: 売上日次集計バッチ

**スケジュール**: 毎日 21:00 (JST)  
**処理内容**:
1. 当日の `payments.status = 'completed'` の注文を集計
2. 集計結果をCSVで S3 にアップロード（`s3://example-shop-reports/daily/YYYYMMDD.csv`）
3. 経営向けSlackチャンネル（`#business-report`）に日次サマリーを投稿

**集計項目**:
- 売上総額（税込）
- 注文件数
- 決済方法別内訳
- カテゴリ別売上

> **TODO**: S3へのアップロードは本番環境のみ。研修・開発環境ではスキップ。

---

### B-07: レコメンド更新バッチ

**スケジュール**: 毎日 18:00 (JST)  
**処理内容**:
1. 過去30日の閲覧・購入データを集計
2. 協調フィルタリングで関連商品スコアを計算
3. Redisにキャッシュ（TTL: 25時間）

> **TODO**: 機械学習モデルへの移行検討中（現在はシンプルなルールベース）。

---

### B-08: 週次レコメンドモデル更新

**スケジュール**: 毎週月曜 18:00 (JST)  
**処理時間**: 約30分  
**注意**: このバッチ実行中はレコメンドAPIのレスポンスが遅延する可能性あり。

---

### B-09: クーポン有効期限チェック

**スケジュール**: 毎日 00:30 (JST)  
**処理内容**:
1. `expires_at < NOW()` かつ `is_active = 1` のクーポンを無効化
2. 無効化件数をログ出力

---

### B-10: 棚卸し差異チェックバッチ

**スケジュール**: 毎日 08:00 (JST)  
**処理内容**:
1. WMS（倉庫管理システム）から実在庫数を取得
2. `products.stock_count` と比較
3. 差異があれば `stock_history` に `change_type='adjustment'` で記録し `stock_count` を更新
4. 差異が累計10個以上の商品は倉庫マネージャーへメール通知

> **TODO**: WMS APIとの本番連携未完了（現在はCSV取り込みで代替）。

---

## 3. バッチ実行基盤

- 実行環境: ECS Scheduled Tasks（AWS EventBridge）
- タイムゾーン: Asia/Tokyo
- 失敗時通知: CloudWatch Alarms → SNS → Slack `#ops-alert`
- ログ保存: CloudWatch Logs（グループ: `/ecs/example-shop/batch`）

---

## 4. リカバリ手順

### 日次集計バッチが失敗した場合

```bash
# 手動再実行（対象日付を指定）
aws ecs run-task \
  --cluster example-shop-prod \
  --task-definition batch-daily-report \
  --overrides '{"containerOverrides":[{"name":"batch","environment":[{"name":"TARGET_DATE","value":"2026-03-10"}]}]}'
```

### 在庫不整合が検出された場合

1. `stock_history` テーブルで当該商品の履歴を確認
2. 倉庫担当に実査を依頼
3. 実査結果をもとに管理画面から `adjustment` レコードを手動追加
4. B-04 を手動再実行して差異が解消されたことを確認

### 入金確認バッチのリカバリ

特定の注文だけ手動でステータス更新が必要な場合:
```bash
# 管理者CLIで入金確認を手動実行
npm run cli -- payment:confirm --order-id=XXX
```

> **TODO**: 管理者CLIコマンドのドキュメント整備が未完了。
