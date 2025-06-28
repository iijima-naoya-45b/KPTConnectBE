# Slack統合機能の設定手順

Slackからの入力でKPTセッションを作成できる機能の設定方法です。

## 📋 必要な設定

### 1. Slack App作成

1. [Slack API](https://api.slack.com/apps)にアクセス
2. "Create New App" → "From scratch"
3. App名とワークスペースを選択

### 2. Slack App設定

#### Bot Token Scopes
`OAuth & Permissions` → `Bot Token Scopes`で以下を追加：
```
- chat:write (メッセージ送信)
- chat:write.public (パブリックチャンネルに投稿)
- commands (スラッシュコマンド)
```

#### Slash Commands
`Slash Commands`で以下のコマンドを作成：

**Command:** `/kpt`
**Request URL:** `https://yourdomain.com/api/v1/slack/commands`
**Short Description:** `KPT振り返りを作成`
**Usage Hint:** `KPT振り返りセッションを作成します`

#### Interactive Components
`Interactivity & Shortcuts`を有効にして：

**Request URL:** `https://yourdomain.com/api/v1/slack/interactive`

#### Event Subscriptions (オプション)
将来の拡張用

### 3. 環境変数設定

`.env`ファイルに以下を追加：

```bash
# Slack Bot Token (xoxb-で始まる)
SLACK_BOT_TOKEN=xoxb-your-bot-token

# Slack Signing Secret (Basic Informationページで確認)
SLACK_SIGNING_SECRET=your-signing-secret

# フロントエンドURL（詳細ボタン用）
FRONTEND_URL=https://your-frontend-domain.com
```

### 4. Gemfile更新とスケジュール設定

```bash
bundle install

# crontabに定期実行スケジュールを追加
bundle exec whenever --update-crontab
```

### 5. アプリをワークスペースにインストール

1. `OAuth & Permissions` → `Install to Workspace`
2. 権限を確認して承認

## 🚀 使用方法

### Slackでの操作

#### 手動でKPT作成
1. **コマンド実行**
   ```
   /kpt
   ```

2. **モーダル入力**
   - セッション名
   - セッション説明（任意）
   - Keep項目（1行ずつ）
   - Problem項目（1行ずつ）
   - Try項目（1行ずつ）

3. **送信**
   - 「作成」ボタンをクリック
   - 成功メッセージがDMで届く

#### 自動リマインダー
- **毎日朝9時**: モチベーション向上のための軽いリマインダー
- **毎日夕方18時**: 1日の振り返りを促すリマインダー
- **統計情報表示**: 今週の実施回数、連続日数、前回実施日
- **ワンクリック作成**: リマインダーから直接KPT作成モーダルを開く

### 入力例

**Keep項目:**
```
・チーム内でのコミュニケーションが活発だった
・計画通りにタスクを進められた
・新しいツールの使い方を覚えた
```

**Problem項目:**
```
・会議の時間が長すぎた
・ドキュメント作成に時間がかかった
・優先順位の判断に迷った
```

**Try項目:**
```
・会議アジェンダを事前に共有する
・テンプレートを活用してドキュメント作成を効率化する
・タスクの優先度を明確にする仕組みを作る
```

## 🔐 セキュリティ

### Slack署名検証
- 全てのリクエストでSlack署名を検証
- タイムスタンプチェック（5分以内）
- リプレイ攻撃防止

### ユーザー認証
- SlackのメールアドレスでKPT Connectユーザーと紐付け
- 該当ユーザーが存在しない場合はエラーメッセージ

## 🛠️ トラブルシューティング

### よくあるエラー

1. **「ユーザーが見つかりません」**
   - SlackのメールアドレスとKPT Connectのアカウントが一致しているか確認
   
2. **「署名が一致しません」**
   - `SLACK_SIGNING_SECRET`が正しく設定されているか確認
   
3. **「モーダルが表示されない」**
   - `SLACK_BOT_TOKEN`が正しく設定されているか確認
   - Bot Token Scopesが設定されているか確認

### ログ確認

```bash
tail -f log/production.log | grep "Slack"
```

## 📊 拡張可能な機能

### 今後追加可能な機能

1. **定期リマインダー**
   - 毎日決まった時間にKPT作成を促す

2. **チーム共有**
   - チャンネルでKPTセッションを共有

3. **AIフィードバック統合**
   - Slack内でAIからのアドバイスを表示

4. **テンプレート機能**
   - よく使うKPT項目のテンプレート

5. **統計レポート**
   - 週次/月次レポートをSlackに送信

## 🔄 フロー図

```
[Slack] /kpt コマンド
    ↓
[Rails] コマンド受信・認証
    ↓
[Slack] モーダル表示
    ↓
[User] 入力・送信
    ↓
[Rails] KPTセッション作成
    ↓
[Slack] 成功メッセージ送信
```

## ⚙️ 技術仕様

### 実装済み機能

1. **Slash Commands**
   - `/kpt`: KPT作成モーダルを開く
   - ユーザー認証（Slackメールアドレスベース）
   - セキュリティ検証（署名検証）

2. **Interactive Components**
   - モーダルでのKPT入力
   - ボタンクリックでの直接アクション
   - エラーハンドリング

3. **定期リマインダー**
   - 毎日2回の自動送信
   - 既に作成済みの場合はスキップ
   - 個人統計の表示
   - ランダムな励ましメッセージ

4. **統計機能**
   - 今週の実施回数
   - 連続実施日数
   - 前回実施日
   - 項目数カウント

### API エンドポイント

- `POST /api/v1/slack/commands` - Slash Commands処理
- `POST /api/v1/slack/interactive` - Interactive Components処理

### バックグラウンドジョブ

- `SlackNotificationJob` - KPT作成時の通知（既存 + AIリアクション）
- `DailyKptReminderJob` - 定期リマインダー送信

### エラーハンドリング

- Slack API エラー
- ユーザー認証エラー
- ネットワークタイムアウト
- JSON解析エラー
- レート制限対応

## 📞 サポート

設定で困った場合は、ログファイルを確認して開発チームにお問い合わせください。

### デバッグ用コマンド

```bash
# 手動でリマインダーテスト
rails runner "DailyKptReminderJob.perform_now"

# 特定ユーザーのSlack ID確認
rails runner "puts User.find_by(email: 'user@example.com')&.slack_user_id"

# crontab確認
bundle exec whenever --write-crontab
``` 