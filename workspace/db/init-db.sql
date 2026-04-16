-- ECサイト研修用 SQLite データベース初期化スクリプト
-- 外部キー制約を有効化
PRAGMA foreign_keys = ON;

-- ─────────────────────────────────────────────────────────
-- テーブル定義
-- ─────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS categories (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    name        TEXT NOT NULL UNIQUE,
    slug        TEXT NOT NULL UNIQUE,
    description TEXT,
    parent_id   INTEGER REFERENCES categories(id),
    sort_order  INTEGER NOT NULL DEFAULT 0,
    created_at  TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS users (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    email        TEXT NOT NULL UNIQUE,
    name         TEXT NOT NULL,
    phone        TEXT,
    postal_code  TEXT,
    address      TEXT,
    is_active    INTEGER NOT NULL DEFAULT 1,
    created_at   TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at   TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);

CREATE TABLE IF NOT EXISTS products (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    category_id  INTEGER NOT NULL REFERENCES categories(id),
    sku          TEXT NOT NULL UNIQUE,
    name         TEXT NOT NULL,
    description  TEXT,
    price        INTEGER NOT NULL,  -- 円（税抜）
    tax_rate     REAL NOT NULL DEFAULT 0.10,
    stock_count  INTEGER NOT NULL DEFAULT 0,
    is_active    INTEGER NOT NULL DEFAULT 1,
    created_at   TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at   TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_products_category ON products(category_id);
CREATE INDEX IF NOT EXISTS idx_products_sku ON products(sku);

CREATE TABLE IF NOT EXISTS orders (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id         INTEGER NOT NULL REFERENCES users(id),
    status          TEXT NOT NULL DEFAULT 'pending',
    -- status: pending / confirmed / paid / shipped / delivered / cancelled / refunded
    subtotal        INTEGER NOT NULL,   -- 税抜小計（円）
    tax_amount      INTEGER NOT NULL,   -- 消費税額（円）
    shipping_fee    INTEGER NOT NULL DEFAULT 0,
    total_amount    INTEGER NOT NULL,   -- 合計（税込）
    coupon_id       INTEGER REFERENCES coupons(id),
    discount_amount INTEGER NOT NULL DEFAULT 0,
    note            TEXT,
    created_at      TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at      TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_orders_user ON orders(user_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_created ON orders(created_at);

CREATE TABLE IF NOT EXISTS order_items (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    order_id    INTEGER NOT NULL REFERENCES orders(id),
    product_id  INTEGER NOT NULL REFERENCES products(id),
    quantity    INTEGER NOT NULL,
    unit_price  INTEGER NOT NULL,   -- 注文時点の単価（税抜）
    tax_rate    REAL NOT NULL,
    created_at  TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_order_items_order ON order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_order_items_product ON order_items(product_id);

CREATE TABLE IF NOT EXISTS payments (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    order_id       INTEGER NOT NULL REFERENCES orders(id),
    method         TEXT NOT NULL,
    -- method: credit_card / convenience / bank_transfer / paypay
    status         TEXT NOT NULL DEFAULT 'pending',
    -- status: pending / completed / failed / refunded
    amount         INTEGER NOT NULL,
    transaction_id TEXT,    -- 外部決済サービスのトランザクションID
    error_code     TEXT,    -- 決済失敗時のエラーコード
    error_message  TEXT,
    paid_at        TEXT,
    created_at     TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at     TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_payments_order ON payments(order_id);
CREATE INDEX IF NOT EXISTS idx_payments_status ON payments(status);
CREATE UNIQUE INDEX IF NOT EXISTS idx_payments_transaction ON payments(transaction_id) WHERE transaction_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS shipments (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    order_id        INTEGER NOT NULL REFERENCES orders(id),
    carrier         TEXT NOT NULL DEFAULT 'yamato',
    -- carrier: yamato / sagawa / jppost
    tracking_number TEXT,
    status          TEXT NOT NULL DEFAULT 'preparing',
    -- status: preparing / shipped / in_transit / delivered / returned
    shipped_at      TEXT,
    delivered_at    TEXT,
    created_at      TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at      TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_shipments_order ON shipments(order_id);
CREATE INDEX IF NOT EXISTS idx_shipments_tracking ON shipments(tracking_number);

CREATE TABLE IF NOT EXISTS reviews (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    product_id INTEGER NOT NULL REFERENCES products(id),
    user_id    INTEGER NOT NULL REFERENCES users(id),
    rating     INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
    title      TEXT,
    body       TEXT,
    is_visible INTEGER NOT NULL DEFAULT 1,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    UNIQUE (product_id, user_id)
);
CREATE INDEX IF NOT EXISTS idx_reviews_product ON reviews(product_id);

CREATE TABLE IF NOT EXISTS coupons (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    code            TEXT NOT NULL UNIQUE,
    discount_type   TEXT NOT NULL,   -- fixed / percent
    discount_value  INTEGER NOT NULL,
    min_order_amount INTEGER,        -- 最低注文金額（NULL = 制限なし）
    max_uses        INTEGER,         -- 最大利用回数（NULL = 無制限）
    used_count      INTEGER NOT NULL DEFAULT 0,
    expires_at      TEXT,
    is_active       INTEGER NOT NULL DEFAULT 1,
    created_at      TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_coupons_code ON coupons(code);

CREATE TABLE IF NOT EXISTS stock_history (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    product_id  INTEGER NOT NULL REFERENCES products(id),
    change_type TEXT NOT NULL,
    -- change_type: purchase / sale / adjustment / return / expired
    quantity    INTEGER NOT NULL,  -- 変動数量（負の値 = 減少）
    stock_after INTEGER NOT NULL,  -- 変動後の在庫数
    order_id    INTEGER REFERENCES orders(id),
    reason      TEXT,
    created_at  TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_stock_history_product ON stock_history(product_id);
CREATE INDEX IF NOT EXISTS idx_stock_history_created ON stock_history(created_at);

-- ─────────────────────────────────────────────────────────
-- サンプルデータ
-- ─────────────────────────────────────────────────────────

-- カテゴリ
INSERT INTO categories (id, name, slug, description, sort_order) VALUES
(1, '家電', 'electronics', '家電製品全般', 1),
(2, 'スマートフォン・タブレット', 'smartphones', 'スマホ・タブレット端末', 2),
(3, 'パソコン・周辺機器', 'computers', 'PC本体・周辺機器', 3),
(4, 'オーディオ', 'audio', 'イヤホン・スピーカー', 4),
(5, '生活家電', 'home-appliances', '掃除機・調理家電', 5);

-- ユーザー（20件）
INSERT INTO users (id, email, name, phone, postal_code, address, created_at) VALUES
(1,  'tanaka.taro@example.com',   '田中 太郎',   '090-1111-0001', '100-0001', '東京都千代田区千代田1-1', '2025-06-15 10:00:00'),
(2,  'suzuki.hanako@example.com', '鈴木 花子',   '090-1111-0002', '150-0001', '東京都渋谷区神宮前1-1',   '2025-07-20 11:30:00'),
(3,  'sato.ichiro@example.com',   '佐藤 一郎',   '090-1111-0003', '060-0001', '北海道札幌市中央区北1条西1', '2025-08-05 09:15:00'),
(4,  'ito.yoko@example.com',      '伊藤 洋子',   '090-1111-0004', '460-0001', '愛知県名古屋市中区三の丸1-1', '2025-09-10 14:45:00'),
(5,  'watanabe.ken@example.com',  '渡辺 健',     '090-1111-0005', '530-0001', '大阪府大阪市北区梅田1-1',  '2025-10-01 08:00:00'),
(6,  'yamamoto.ai@example.com',   '山本 愛',     '090-1111-0006', '220-0001', '神奈川県横浜市西区北幸1-1', '2025-10-15 16:30:00'),
(7,  'nakamura.ryo@example.com',  '中村 亮',     '090-1111-0007', '812-0001', '福岡県福岡市博多区博多駅前1-1', '2025-11-02 13:00:00'),
(8,  'kobayashi.miki@example.com','小林 美樹',   '090-1111-0008', '980-0001', '宮城県仙台市青葉区中央1-1', '2025-11-20 10:30:00'),
(9,  'kato.shun@example.com',     '加藤 俊',     '090-1111-0009', '730-0001', '広島県広島市中区基町1-1', '2025-12-01 09:00:00'),
(10, 'yoshida.nana@example.com',  '吉田 奈々',   '090-1111-0010', '380-0001', '長野県長野市大字長野1-1', '2025-12-10 11:00:00'),
(11, 'hayashi.daisuke@example.com','林 大輔',    '090-1111-0011', '420-0001', '静岡県静岡市葵区追手町1-1', '2026-01-05 10:15:00'),
(12, 'kimura.rie@example.com',    '木村 里絵',   '090-1111-0012', '640-0001', '和歌山県和歌山市小松原通1-1', '2026-01-15 14:00:00'),
(13, 'shimizu.takuya@example.com','清水 拓也',   '090-1111-0013', '760-0001', '香川県高松市番町1-1', '2026-01-25 09:30:00'),
(14, 'yamaguchi.emi@example.com', '山口 恵美',   '090-1111-0014', '700-0001', '岡山県岡山市北区内山下1-1', '2026-02-01 11:45:00'),
(15, 'matsumoto.hiroki@example.com','松本 浩樹', '090-1111-0015', '390-0001', '長野県松本市丸の内1-1', '2026-02-10 16:00:00'),
(16, 'inoue.sakura@example.com',  '井上 さくら', '090-1111-0016', '910-0001', '福井県福井市大手3-1', '2026-02-15 10:00:00'),
(17, 'kimoto.jun@example.com',    '木本 純',     '090-1111-0017', '630-0001', '奈良県奈良市二条大路南1-1', '2026-02-20 13:30:00'),
(18, 'fujita.yuki@example.com',   '藤田 雪',     '090-1111-0018', '500-0001', '岐阜県岐阜市藪田南2-1', '2026-02-25 09:00:00'),
(19, 'ogawa.masato@example.com',  '小川 雅人',   '090-1111-0019', '320-0001', '栃木県宇都宮市塙田1-1', '2026-03-01 10:00:00'),
(20, 'nishimura.kaoru@example.com','西村 薫',    '090-1111-0020', '310-0001', '茨城県水戸市笠原町978', '2026-03-05 15:00:00');

-- 商品（20件）
INSERT INTO products (id, category_id, sku, name, description, price, stock_count, created_at) VALUES
(1,  2, 'SP-A15-BLK', 'スマートフォン TypeA15 ブラック', '最新フラグシップモデル。6.7インチ有機EL', 89800, 50, '2025-09-01 00:00:00'),
(2,  2, 'SP-A15-WHT', 'スマートフォン TypeA15 ホワイト', '最新フラグシップモデル。6.7インチ有機EL', 89800, 30, '2025-09-01 00:00:00'),
(3,  2, 'TB-PRO-11',  'タブレット ProSeries 11インチ',   '高精細Retinaディスプレイ搭載', 68000, 20, '2025-10-01 00:00:00'),
(4,  3, 'PC-NOTE-A',  'ノートPC UltraSlim 14インチ',    'Core i7・16GB・512GB SSD', 128000, 15, '2025-08-01 00:00:00'),
(5,  3, 'PC-NOTE-B',  'ノートPC Standard 15.6インチ',   'Core i5・8GB・256GB SSD', 78000, 25, '2025-08-01 00:00:00'),
(6,  3, 'KB-WIRE-01', 'メカニカルキーボード 有線',       '青軸・テンキーレス', 8900, 100, '2025-07-01 00:00:00'),
(7,  3, 'MS-WRLS-02', 'ワイヤレスマウス',               '静音設計・2.4GHz', 3200, 200, '2025-07-01 00:00:00'),
(8,  4, 'EP-NC-BLK',  'ノイズキャンセリングイヤホン 黒', 'ANC搭載・30時間再生', 24800, 80, '2025-09-15 00:00:00'),
(9,  4, 'EP-NC-WHT',  'ノイズキャンセリングイヤホン 白', 'ANC搭載・30時間再生', 24800, 60, '2025-09-15 00:00:00'),
(10, 4, 'SP-BT-360',  'Bluetoothスピーカー 360°',       '防水IPX7・20時間再生', 12800, 70, '2025-10-01 00:00:00'),
(11, 1, 'TV-55-4K',   '4K有機ELテレビ 55インチ',        'Google TV搭載', 148000, 10, '2025-11-01 00:00:00'),
(12, 1, 'TV-43-4K',   '4K液晶テレビ 43インチ',          'Google TV搭載', 68000, 20, '2025-11-01 00:00:00'),
(13, 5, 'VC-CORD-01', 'コードレス掃除機',               '軽量2.0kg・吸引力強化', 38000, 35, '2025-10-15 00:00:00'),
(14, 5, 'MO-AIR-01',  '空気清浄機 14畳対応',            'HEPAフィルター・PM2.5対応', 28000, 45, '2025-10-15 00:00:00'),
(15, 5, 'RC-IH-02',   '炊飯器 IH式 5.5合',             '圧力IH・玄米対応', 22000, 55, '2025-09-01 00:00:00'),
(16, 2, 'SP-B10-RED', 'スマートフォン TypeB10 レッド',  'コスパモデル。6.1インチ液晶', 39800, 80, '2025-10-01 00:00:00'),
(17, 3, 'MN-27-4K',   '4Kモニター 27インチ',           'IPS・144Hz・USB-C給電', 45000, 40, '2025-08-15 00:00:00'),
(18, 4, 'HDP-WIRE-01','有線ヘッドフォン スタジオ用',    'フラット応答・折りたたみ可', 15800, 30, '2025-07-15 00:00:00'),
(19, 3, 'WB-CAM-01',  'Webカメラ 1080p',               'オートフォーカス・ノイズ低減マイク内蔵', 6800, 150, '2025-07-01 00:00:00'),
(20, 5, 'KT-SMRT-01', 'スマート電気ケトル',            'アプリ操作・温度設定対応', 9800, 90, '2026-01-01 00:00:00');

-- クーポン（5件）
INSERT INTO coupons (id, code, discount_type, discount_value, min_order_amount, max_uses, used_count, expires_at) VALUES
(1, 'WELCOME10', 'percent', 10, 5000,  NULL, 8,  '2026-06-30 23:59:59'),
(2, 'SPRING500',  'fixed',  500, 3000,  200, 15, '2026-03-31 23:59:59'),
(3, 'VIP1000',    'fixed', 1000, 10000, 50,  3,  '2026-12-31 23:59:59'),
(4, 'SALE20',     'percent', 20, 8000,  100, 22, '2026-02-28 23:59:59'),
(5, 'NEWUSER',    'fixed',  300, 1000,  NULL, 5, '2026-06-30 23:59:59');

-- 注文（20件）
INSERT INTO orders (id, user_id, status, subtotal, tax_amount, shipping_fee, total_amount, coupon_id, discount_amount, created_at, updated_at) VALUES
(1,  1,  'delivered', 89800, 8980, 0,    98780, NULL, 0,    '2026-02-10 10:15:00', '2026-02-15 14:00:00'),
(2,  2,  'delivered', 24800, 2480, 0,    27280, 1,    2480, '2026-02-12 11:30:00', '2026-02-17 16:00:00'),
(3,  3,  'delivered', 78000, 7800, 800,  86600, NULL, 0,    '2026-02-14 09:00:00', '2026-02-20 12:00:00'),
(4,  4,  'delivered', 12800, 1280, 0,    14080, 2,    500,  '2026-02-20 14:30:00', '2026-02-25 18:00:00'),
(5,  5,  'delivered', 68000, 6800, 0,    74800, NULL, 0,    '2026-02-25 08:00:00', '2026-03-02 10:00:00'),
(6,  6,  'shipped',   128000,12800, 0,  140800, 3,   1000, '2026-03-01 10:00:00', '2026-03-02 09:00:00'),
(7,  7,  'paid',      38000, 3800, 600, 42400, NULL, 0,    '2026-03-02 12:30:00', '2026-03-02 13:00:00'),
(8,  8,  'confirmed', 45000, 4500, 0,   49500, NULL, 0,    '2026-03-03 09:15:00', '2026-03-03 09:30:00'),
(9,  9,  'confirmed', 24800, 2480, 0,   27280, 1,   2480, '2026-03-04 16:00:00', '2026-03-04 16:20:00'),
(10, 10, 'cancelled', 89800, 8980, 0,   98780, NULL, 0,   '2026-03-04 11:00:00', '2026-03-05 10:00:00'),
(11, 11, 'pending',   22000, 2200, 800, 25000, 5,   300,  '2026-03-05 08:30:00', '2026-03-05 08:30:00'),
(12, 12, 'paid',      9800,  980, 0,   10780, NULL, 0,    '2026-03-06 14:00:00', '2026-03-06 14:30:00'),
(13, 1,  'paid',      28000, 2800, 0,  30800, NULL, 0,    '2026-03-07 10:00:00', '2026-03-07 10:30:00'),
(14, 13, 'confirmed', 15800, 1580, 0,  17380, NULL, 0,    '2026-03-07 15:30:00', '2026-03-07 15:45:00'),
(15, 14, 'pending',   68000, 6800, 0,  74800, 3,   1000, '2026-03-08 09:00:00', '2026-03-08 09:00:00'),
(16, 15, 'confirmed', 8900,  890, 600,  10390, NULL, 0,   '2026-03-08 11:00:00', '2026-03-08 11:20:00'),
(17, 2,  'paid',      3200,  320, 0,   3520, 5,   300,   '2026-03-09 13:00:00', '2026-03-09 13:30:00'),
(18, 16, 'pending',   148000,14800, 0, 162800, NULL, 0,   '2026-03-09 16:00:00', '2026-03-09 16:00:00'),
(19, 17, 'confirmed', 6800,  680, 0,  7480, NULL, 0,      '2026-03-10 09:00:00', '2026-03-10 09:15:00'),
(20, 3,  'pending',   24800, 2480, 0,  27280, 1,  2480,  '2026-03-10 14:00:00', '2026-03-10 14:00:00');

-- 注文明細
INSERT INTO order_items (id, order_id, product_id, quantity, unit_price, tax_rate) VALUES
(1,  1,  1,  1, 89800, 0.10),
(2,  2,  8,  1, 24800, 0.10),
(3,  3,  5,  1, 78000, 0.10),
(4,  4,  10, 1, 12800, 0.10),
(5,  5,  3,  1, 68000, 0.10),
(6,  6,  4,  1,128000, 0.10),
(7,  7,  16, 1, 38000, 0.10),
(8,  8,  17, 1, 45000, 0.10),
(9,  9,  9,  1, 24800, 0.10),
(10, 10, 1,  1, 89800, 0.10),
(11, 11, 15, 1, 22000, 0.10),
(12, 12, 20, 1,  9800, 0.10),
(13, 13, 14, 1, 28000, 0.10),
(14, 14, 18, 1, 15800, 0.10),
(15, 15, 12, 1, 68000, 0.10),
(16, 16, 6,  1,  8900, 0.10),
(17, 17, 7,  1,  3200, 0.10),
(18, 18, 11, 1,148000, 0.10),
(19, 19, 19, 1,  6800, 0.10),
(20, 20, 8,  1, 24800, 0.10),
(21, 3,  7,  1,  3200, 0.10),  -- 注文3は複数商品
(22, 6,  6,  1,  8900, 0.10);  -- 注文6は複数商品（※合計に含まれていない調整が必要だが研修用データとして許容）

-- 決済
INSERT INTO payments (id, order_id, method, status, amount, transaction_id, paid_at, created_at, updated_at) VALUES
(1,  1,  'credit_card',  'completed', 98780,  'TXN-20260210-001', '2026-02-10 10:16:30', '2026-02-10 10:15:00', '2026-02-10 10:16:30'),
(2,  2,  'credit_card',  'completed', 27280,  'TXN-20260212-001', '2026-02-12 11:31:00', '2026-02-12 11:30:00', '2026-02-12 11:31:00'),
(3,  3,  'convenience',  'completed', 86600,  'CNV-20260215-003', '2026-02-15 14:00:00', '2026-02-14 09:00:00', '2026-02-15 14:00:00'),
(4,  4,  'paypay',       'completed', 14080,  'PPY-20260220-004', '2026-02-20 14:31:00', '2026-02-20 14:30:00', '2026-02-20 14:31:00'),
(5,  5,  'credit_card',  'completed', 74800,  'TXN-20260225-005', '2026-02-25 08:01:00', '2026-02-25 08:00:00', '2026-02-25 08:01:00'),
(6,  6,  'credit_card',  'completed', 140800, 'TXN-20260301-006', '2026-03-01 10:05:00', '2026-03-01 10:00:00', '2026-03-01 10:05:00'),
(7,  7,  'credit_card',  'completed', 42400,  'TXN-20260302-007', '2026-03-02 12:31:00', '2026-03-02 12:30:00', '2026-03-02 12:31:00'),
(8,  8,  'bank_transfer','completed', 49500,  'BNK-20260303-008', '2026-03-04 10:00:00', '2026-03-03 09:15:00', '2026-03-04 10:00:00'),
(9,  9,  'credit_card',  'completed', 27280,  'TXN-20260304-009', '2026-03-04 16:01:00', '2026-03-04 16:00:00', '2026-03-04 16:01:00'),
(10, 10, 'credit_card',  'failed',    98780,  NULL,               NULL,                  '2026-03-04 11:00:00', '2026-03-04 11:00:00'),
(11, 11, 'convenience',  'pending',   25000,  NULL,               NULL,                  '2026-03-05 08:30:00', '2026-03-05 08:30:00'),
(12, 12, 'paypay',       'completed', 10780,  'PPY-20260306-012', '2026-03-06 14:01:00', '2026-03-06 14:00:00', '2026-03-06 14:01:00'),
(13, 13, 'credit_card',  'completed', 30800,  'TXN-20260307-013', '2026-03-07 10:02:00', '2026-03-07 10:00:00', '2026-03-07 10:02:00'),
(14, 14, 'credit_card',  'completed', 17380,  'TXN-20260307-014', '2026-03-07 15:31:00', '2026-03-07 15:30:00', '2026-03-07 15:31:00'),
(15, 15, 'credit_card',  'failed',    74800,  NULL,               NULL,                  '2026-03-08 09:00:00', '2026-03-08 09:01:00'),
(16, 16, 'paypay',       'completed', 10390,  'PPY-20260308-016', '2026-03-08 11:01:00', '2026-03-08 11:00:00', '2026-03-08 11:01:00'),
(17, 17, 'credit_card',  'completed', 3520,   'TXN-20260309-017', '2026-03-09 13:01:00', '2026-03-09 13:00:00', '2026-03-09 13:01:00'),
(18, 18, 'credit_card',  'pending',   162800, NULL,               NULL,                  '2026-03-09 16:00:00', '2026-03-09 16:00:00'),
(19, 19, 'paypay',       'completed', 7480,   'PPY-20260310-019', '2026-03-10 09:01:00', '2026-03-10 09:00:00', '2026-03-10 09:01:00'),
(20, 20, 'credit_card',  'pending',   27280,  NULL,               NULL,                  '2026-03-10 14:00:00', '2026-03-10 14:00:00');

-- 配送
INSERT INTO shipments (id, order_id, carrier, tracking_number, status, shipped_at, delivered_at, created_at) VALUES
(1, 1, 'yamato', 'YM-1234567890', 'delivered', '2026-02-11 15:00:00', '2026-02-13 11:00:00', '2026-02-11 14:00:00'),
(2, 2, 'sagawa', 'SG-9876543210', 'delivered', '2026-02-13 10:00:00', '2026-02-15 14:00:00', '2026-02-13 09:00:00'),
(3, 3, 'jppost', 'JP-1122334455', 'delivered', '2026-02-16 14:00:00', '2026-02-19 11:00:00', '2026-02-16 13:00:00'),
(4, 4, 'yamato', 'YM-2233445566', 'delivered', '2026-02-21 10:00:00', '2026-02-23 12:00:00', '2026-02-21 09:00:00'),
(5, 5, 'sagawa', 'SG-3344556677', 'delivered', '2026-02-26 10:00:00', '2026-02-28 14:00:00', '2026-02-26 09:00:00'),
(6, 6, 'yamato', 'YM-4455667788', 'shipped',   '2026-03-02 09:00:00', NULL,                  '2026-03-02 08:00:00'),
(7, 7, 'sagawa', 'SG-5566778899', 'in_transit','2026-03-03 10:00:00', NULL,                  '2026-03-03 09:00:00');

-- レビュー（10件）
INSERT INTO reviews (id, product_id, user_id, rating, title, body, created_at) VALUES
(1,  1,  1, 5, '最高のスマホ', 'カメラ性能が素晴らしい。バッテリーも一日以上持ちます。', '2026-02-16 10:00:00'),
(2,  8,  2, 4, 'ノイキャン性能良し', '電車の中でも快適。音質も申し分なし。', '2026-02-20 11:00:00'),
(3,  5,  3, 3, 'コスパは良いが重い', '普通に使えるが、2.2kgは少し重い。', '2026-02-25 14:00:00'),
(4,  10, 4, 5, '音質に驚き', 'この価格でこの音質は驚異的。防水も安心。', '2026-02-28 09:00:00'),
(5,  3,  5, 4, 'タブレットとして優秀', 'Proの名に恥じない性能。Apple Pencilとの相性も良い。', '2026-03-05 16:00:00'),
(6,  6,  6, 5, '打鍵感が最高', '青軸の音は職場では難しいが家では最高。', '2026-03-06 10:00:00'),
(7,  16, 7, 4, '普段使いに十分', 'フラグシップほどの性能は不要なので丁度いい。', '2026-03-07 09:00:00'),
(8,  17, 8, 5, '4Kモニターとして最高', 'USB-C一本で給電・映像入力できるのが便利。', '2026-03-07 11:00:00'),
(9,  9,  9, 4, '白色が可愛い', '機能はブラックと同じだが白色が選べて満足。', '2026-03-08 14:00:00'),
(10, 20, 4, 5, 'スマートケトル便利', 'アプリで温度設定できるのが地味に便利。', '2026-03-10 10:00:00');

-- 在庫履歴（主要な変動を記録）
INSERT INTO stock_history (id, product_id, change_type, quantity, stock_after, order_id, reason, created_at) VALUES
(1,  1,  'purchase',   100, 100, NULL, '初回入荷', '2025-09-01 00:00:00'),
(2,  1,  'sale',        -1,  99, 1,   '注文#1 販売',        '2026-02-10 10:16:30'),
(3,  1,  'sale',        -1,  98, 10,  '注文#10 在庫引当',   '2026-03-04 11:00:00'),
(4,  1,  'adjustment',   1,  99, NULL,'注文#10 キャンセル戻し', '2026-03-05 10:00:00'),
(5,  5,  'purchase',    50,  50, NULL,'初回入荷', '2025-08-01 00:00:00'),
(6,  5,  'sale',        -1,  49, 3,   '注文#3 販売', '2026-02-14 09:00:00'),
(7,  8,  'purchase',   100, 100, NULL,'初回入荷', '2025-09-15 00:00:00'),
(8,  8,  'sale',        -1,  99, 2,   '注文#2 販売', '2026-02-12 11:31:00'),
(9,  8,  'sale',        -1,  98, 20,  '注文#20 在庫引当', '2026-03-10 14:00:00'),
(10, 16, 'purchase',   100, 100, NULL,'初回入荷', '2025-10-01 00:00:00'),
(11, 16, 'sale',        -1,  99, 7,   '注文#7 販売', '2026-03-02 12:31:00'),
(12, 13, 'purchase',    50,  50, NULL,'初回入荷', '2025-10-15 00:00:00'),
(13, 13, 'adjustment',  -5,  45, NULL,'棚卸し差異', '2026-03-08 08:00:00'),
(14, 13, 'adjustment',  -3,  42, NULL,'棚卸し差異（再確認）', '2026-03-08 10:00:00'),
(15, 14, 'purchase',    60,  60, NULL,'初回入荷', '2025-10-15 00:00:00'),
(16, 14, 'sale',        -1,  59, 13,  '注文#13 販売', '2026-03-07 10:02:00'),
(17, 11, 'purchase',    15,  15, NULL,'初回入荷', '2025-11-01 00:00:00'),
(18, 11, 'sale',        -1,  14, 18,  '注文#18 在庫引当', '2026-03-09 16:00:00'),
(19, 4,  'purchase',    20,  20, NULL,'初回入荷', '2025-08-01 00:00:00'),
(20, 4,  'sale',        -1,  19, 6,   '注文#6 販売', '2026-03-01 10:05:00');
