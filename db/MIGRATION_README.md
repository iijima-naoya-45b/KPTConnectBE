# KPTアプリ データベースマイグレーション

## 📋 概要

KPT（Keep, Problem, Try）振り返り支援アプリのためのRailsマイグレーションファイル一覧です。
個人ユーザーの振り返り活動をサポートし、AI分析、チャート可視化、Stripe課金システムを含む包括的な機能を提供します。

## 🗂️ マイグレーションファイル一覧

### 基盤設定
0. **`20250531120000_enable_extensions.rb`** - PostgreSQL拡張機能有効化
1. **`20250531120001_add_kpt_fields_to_users.rb`** - 既存usersテーブルにKPT用カラム追加

### Core機能テーブル
2. **`20250531120002_create_kpt_sessions.rb`** - KPTセッション管理
3. **`20250531120003_create_kpt_items.rb`** - Keep/Problem/Try各項目
4. **`20250531120004_create_work_logs.rb`** - 作業ログ・活動記録
5. **`20250531120005_create_work_log_kpt_links.rb`** - 作業ログ↔KPT関連付け

### 分析・可視化テーブル
6. **`20250531120006_create_insights.rb`** - AI分析結果・インサイト
7. **`20250531120007_create_charts.rb`** - チャート設定・可視化

### 課金システムテーブル
8. **`20250531120008_create_subscriptions.rb`** - Stripeサブスクリプション
9. **`20250531120009_create_payments.rb`** - 支払い履歴
10. **`20250531120010_create_payment_methods.rb`** - 支払い方法

### システム管理テーブル
11. **`20250531120011_create_system_settings.rb`** - システム設定
12. **`20250531120012_create_user_settings.rb`** - ユーザー個人設定

### 拡張機能
13. **`20250531120013_add_duration_to_work_logs.rb`** - 継続時間計算カラム追加
14. **`20250531120014_create_analysis_views.rb`** - 分析用ビュー作成

### タグ管理システム
15. **`20250531120015_create_tags_and_tag_associations.rb`** - タグテーブル・中間テーブル作成
16. **`20250531120016_add_kpt_session_tags.rb`** - KPTセッション-タグ関連付け
17. **`20250531120017_migrate_array_tags_to_normalized_tags.rb`** - 配列タグから正規化タグへの移行

### 既存テーブル（変更不可）
- **`20250423085555_create_users.rb`** - 基本usersテーブル（email, username, provider, uid）
- **`20250517062524_create_authentications.rb`** - 認証情報テーブル

## 🔧 整合性修正内容

### 修正された問題
1. **テーブル名競合解決**: 新しいusersテーブル作成を削除し、既存テーブルへのカラム追加に変更
2. **ID型統一**: 既存usersテーブル（INTEGER ID）に合わせて外部キー参照を統一
3. **拡張機能設定**: pgcrypto拡張機能を最初に有効化するマイグレーション追加

### ハイブリッド設計
- **usersテーブル**: INTEGER ID（既存システムとの互換性）
- **KPT関連テーブル**: UUID ID（スケーラビリティと分散システム対応）
- **外部キー**: usersテーブルへの参照はINTEGER型で統一

## 🚀 実行手順

### 1. 前提条件確認
```bash
# PostgreSQLが動作していることを確認
rails db:version

# 必要な拡張機能がインストールされていることを確認（UUIDサポート）
rails runner "ActiveRecord::Base.connection.execute('SELECT * FROM pg_available_extensions WHERE name = \'pgcrypto\';')"
```

### 2. マイグレーション実行
```bash
# 全マイグレーションを実行
rails db:migrate

# 特定のマイグレーションまで実行する場合
rails db:migrate VERSION=20250531120017

# マイグレーション状態確認
rails db:migrate:status
```

### 3. ロールバック（必要に応じて）
```bash
# 最後のマイグレーションをロールバック
rails db:rollback

# 特定のバージョンまでロールバック
rails db:rollback TO=20250531120015

# 全てロールバック（注意: 全データが削除されます）
rails db:rollback VERSION=0
```

## 🗄️ 作成されるテーブル詳細

### ユーザー関連
- **users**: ユーザー基本情報（既存: email, username, provider, uid + 追加: name, avatar_url, stripe_customer_id, timezone, language, is_active, email_verified_at, last_login_at）
- **authentications**: OAuth認証情報（既存テーブル）
- **user_settings**: 個人設定（通知、テーマ、自動保存など）

### KPT機能
- **kpt_sessions**: 振り返りセッション（UUID ID、タイトル、説明、ステータス、タグ）
- **kpt_items**: KPT項目（UUID ID、種類、内容、優先度、感情・影響度スコア）

### 作業ログ
- **work_logs**: 作業記録（UUID ID、時間、カテゴリ、各種スコア、場所）
- **work_log_kpt_links**: 作業ログとKPTの関連付け（多対多）

### 分析・可視化
- **insights**: AI分析結果（UUID ID、JSONB形式、信頼度スコア）
- **charts**: チャート設定（UUID ID、種類、設定、クエリ）

### 課金・決済
- **subscriptions**: サブスクリプション情報（UUID ID、Stripe連携）
- **payments**: 支払い履歴（UUID ID、金額、ステータス、レシート）
- **payment_methods**: 支払い方法（UUID ID、カード情報、デフォルト設定）

### システム
- **system_settings**: アプリ全体設定（バージョン、機能フラグ）

### タグ管理システム
- **tags**: 共通タグマスター（UUID ID、名前、作成日時）
- **kpt_session_tags**: KPTセッション-タグ関連付け（多対多）
- **kpt_item_tags**: KPT項目-タグ関連付け（多対多）
- **work_log_tags**: 作業ログ-タグ関連付け（多対多）

## 🔧 特徴的な機能

### ハイブリッドID設計
```ruby
# usersテーブル：INTEGER ID（既存システム互換）
create_table :users do |t|
  # 既存フィールド...
end

# KPT関連テーブル：UUID ID + INTEGER外部キー
create_table :kpt_sessions, id: :uuid do |t|
  t.references :user, null: false, foreign_key: true, type: :integer
  # その他フィールド...
end
```

### PostgreSQL配列型
```ruby
t.text :tags, array: true, default: []
```

### JSONB型
```ruby
t.jsonb :content, null: false
t.jsonb :config, null: false
```

### 制約チェック
```ruby
t.check_constraint "type IN ('keep', 'problem', 'try')", 
                   name: 'check_kpt_items_type'
```

### 正規化されたタグ管理
```ruby
# tagsテーブル
create_table :tags, id: :uuid do |t|
  t.string :name, null: false, limit: 100
  t.timestamp :created_at, null: false
end
add_index :tags, :name, unique: true

# 中間テーブル（例：KPT項目とタグ）
create_table :kpt_item_tags, id: :uuid do |t|
  t.references :kpt_item, null: false, foreign_key: true, type: :uuid
  t.references :tag, null: false, foreign_key: true, type: :uuid
  t.timestamp :created_at, null: false
end
add_index :kpt_item_tags, [:kpt_item_id, :tag_id], unique: true
```

### 計算カラム（PostgreSQL）
```sql
ALTER TABLE work_logs 
ADD COLUMN duration_minutes INTEGER 
GENERATED ALWAYS AS (
  CASE 
    WHEN ended_at IS NOT NULL THEN 
      EXTRACT(EPOCH FROM (ended_at - started_at))/60
    ELSE NULL 
  END
) STORED;
```

### 分析用ビュー
```sql
CREATE VIEW user_kpt_stats AS
SELECT 
  u.id as user_id,
  u.name as user_name,
  COUNT(DISTINCT s.id) as total_sessions,
  -- その他統計項目
FROM users u
LEFT JOIN kpt_sessions s ON u.id = s.user_id
LEFT JOIN kpt_items i ON s.id = i.kpt_session_id
GROUP BY u.id, u.name;
```

## 📊 インデックス戦略

### パフォーマンス最適化
- **外部キー**: 全ての関連付けにインデックス
- **検索頻度高**: user_id, created_at, status
- **GINインデックス**: 配列・JSON検索
- **複合インデックス**: よく組み合わせる条件
- **ユニーク制約**: 重複防止（タグ名、中間テーブルの組み合わせ）

### 例
```ruby
add_index :kpt_items, :kpt_session_id
add_index :kpt_items, :type
add_index :kpt_items, :tags, using: :gin
add_index :kpt_items, [:user_id, :type]

# タグ関連のインデックス
add_index :tags, :name, unique: true
add_index :kpt_item_tags, [:kpt_item_id, :tag_id], unique: true
```

## 🏷️ タグ管理システム

### 設計思想
- **正規化**: タグを独立したテーブルで管理
- **重複排除**: 同一名のタグは1つのみ存在
- **柔軟性**: 複数エンティティ（KPTセッション、項目、作業ログ）で共通利用
- **パフォーマンス**: 検索・集計の最適化

### 移行戦略
1. **段階的移行**: 既存の配列ベースと新しい正規化システムを並行運用
2. **データ保持**: 移行時のデータロス防止
3. **ロールバック対応**: 問題発生時の復旧機能

### 使用例
```sql
-- 特定タグが付いたKPT項目を検索
SELECT i.* FROM kpt_items i
JOIN kpt_item_tags it ON i.id = it.kpt_item_id
JOIN tags t ON it.tag_id = t.id
WHERE t.name = 'レビュー';

-- 最も使用頻度の高いタグを取得
SELECT t.name, COUNT(*) as usage_count
FROM tags t
JOIN kpt_item_tags it ON t.id = it.tag_id
GROUP BY t.id, t.name
ORDER BY usage_count DESC;
```

## ⚠️ 注意事項

### PostgreSQL要件
- PostgreSQL 12以上を推奨
- `pgcrypto`拡張が必要（UUID生成）
- JSONB、配列型、計算カラムを使用

### Stripe連携
- Stripe Webhookの設定が必要
- 本番環境では適切なシークレットキーを設定

### データ移行
- 本番環境では十分なバックアップを取得してから実行
- 大量データがある場合は段階的に実行を検討
- タグ移行時は配列データと正規化データの整合性確認が必要

### ハイブリッドID設計の考慮事項
- 既存システムとの互換性を保持
- 新機能はUUIDでスケーラビリティを確保
- 外部キー参照は型を統一（usersテーブルはINTEGER）

### タグシステム移行
- 既存の配列ベースのタグデータは自動的に正規化テーブルに移行されます
- 移行後も配列カラムは残りますが、新しいアプリケーションでは正規化テーブルを使用してください
- ロールバック時は正規化データから配列に復元されますが、完全性は保証されません

## 🔍 確認コマンド

### テーブル確認
```bash
# 作成されたテーブル一覧
rails runner "puts ActiveRecord::Base.connection.tables.sort"

# 特定テーブルの構造確認
rails runner "puts ActiveRecord::Base.connection.columns(:users).map(&:name)"
```

### タグデータ確認
```bash
# タグ一覧確認
rails runner "puts Tag.all.pluck(:name)"

# タグ使用状況確認
rails runner "puts Tag.joins(:kpt_item_tags).group(:name).count"
```

### 外部キー確認
```bash
# 外部キー制約確認
rails runner "puts ActiveRecord::Base.connection.foreign_keys(:kpt_sessions)"
```

### ビュー確認
```bash
# 作成されたビュー確認
rails runner "puts ActiveRecord::Base.connection.execute('SELECT viewname FROM pg_views WHERE schemaname = \'public\';').values.flatten"
```

### インデックス確認
```bash
# インデックス一覧確認
rails runner "puts ActiveRecord::Base.connection.indexes(:tags).map(&:name)"
```

---

このマイグレーションにより、既存システムとの互換性を保ちながら、KPTアプリの全機能をサポートする完全なデータベースが構築されます。 