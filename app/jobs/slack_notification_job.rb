class SlackNotificationJob < ApplicationJob
  queue_as :default

  def perform(kpt_session_id)
    Rails.logger.info "SlackNotificationJob開始: KPT Session ID: #{kpt_session_id}"
    Rails.logger.info "SlackNotificationJob: 現在のスレッド: #{Thread.current.object_id}"
    
    kpt_session = KptSession.find_by(id: kpt_session_id)
    unless kpt_session
      Rails.logger.error "SlackNotificationJob: KPT Sessionが見つかりません。ID: #{kpt_session_id}"
      return
    end

    user = kpt_session.user
    unless user
      Rails.logger.error "SlackNotificationJob: ユーザーが見つかりません。KPT Session ID: #{kpt_session_id}"
      return
    end

    Rails.logger.info "SlackNotificationJob: ユーザー情報確認 - ID: #{user.id}, Email: #{user.email}"
    Rails.logger.info "SlackNotificationJob: Slack通知設定 - enabled: #{user.slack_notification_enabled?}, webhook_url: #{user.slack_webhook_url.present?}"

    unless user.slack_notification_enabled? && user.slack_webhook_url.present?
      Rails.logger.info "SlackNotificationJob: Slack通知が無効またはWebhook URLが設定されていません"
      Rails.logger.info "SlackNotificationJob: enabled: #{user.slack_notification_enabled?}, webhook_url: #{user.slack_webhook_url}"
      return
    end

    begin
      Rails.logger.info "SlackNotificationJob: Slack通知送信開始"
      
      # HTTPクライアントを使用してSlack WebhookにPOST
      uri = URI(user.slack_webhook_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 10
      http.read_timeout = 10

      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request.body = build_rich_slack_message(kpt_session, user).to_json

      Rails.logger.info "SlackNotificationJob: リクエスト送信 - URL: #{uri.host}, Body size: #{request.body.length}"

      response = http.request(request)

      if response.is_a?(Net::HTTPSuccess)
        Rails.logger.info "SlackNotificationJob: 通知送信成功 - Response: #{response.code}"
        Rails.logger.info "SlackNotificationJob: Response body: #{response.body}"
      else
        Rails.logger.error "Slack通知の送信に失敗しました。 KPT Session ID: #{kpt_session_id}, User ID: #{user.id}, Response: #{response.code} #{response.body}"
      end
    rescue => e
      Rails.logger.error "Slack通知の送信に失敗しました。 KPT Session ID: #{kpt_session_id}, User ID: #{user.id}, Error: #{e.message}"
      Rails.logger.error "SlackNotificationJob: エラーバックトレース: #{e.backtrace.join("\n")}"
    end
  end

  private

  def build_rich_slack_message(kpt_session, user)
    keep_items = kpt_session.kpt_items.where(type: 'keep')
    problem_items = kpt_session.kpt_items.where(type: 'problem')
    try_items = kpt_session.kpt_items.where(type: 'try')

    Rails.logger.info "SlackNotificationJob: メッセージ構築 - Keep: #{keep_items.count}, Problem: #{problem_items.count}, Try: #{try_items.count}"

    blocks = [
      # ヘッダー
      {
        type: "header",
        text: {
          type: "plain_text",
          text: "🎉 新しいKPTセッションが作成されました！"
        }
      },
      # セッション基本情報
      {
        type: "section",
        fields: [
          {
            type: "mrkdwn",
            text: "*📝 セッション名:*\n#{kpt_session.title}"
          },
          {
            type: "mrkdwn",
            text: "*📊 合計項目数:*\n#{kpt_session.kpt_items.count}件"
          }
        ]
      }
    ]

    # セッション説明がある場合
    if kpt_session.description.present?
      blocks << {
        type: "section",
        text: {
          type: "mrkdwn",
          text: "*📋 セッション説明:*\n#{kpt_session.description}"
        }
      }
    end

    # Keep項目の詳細
    if keep_items.any?
      blocks << {
        type: "section",
        text: {
          type: "mrkdwn",
          text: "*✅ Keep（継続したいこと）:*"
        }
      }
      
      keep_items.each_with_index do |item, index|
        blocks << {
          type: "section",
          text: {
            type: "mrkdwn",
            text: format_kpt_item_content(item, index + 1)
          }
        }
      end
    end

    # Problem項目の詳細
    if problem_items.any?
      blocks << {
        type: "section",
        text: {
          type: "mrkdwn",
          text: "*⚠️ Problem（改善したいこと）:*"
        }
      }
      
      problem_items.each_with_index do |item, index|
        blocks << {
          type: "section",
          text: {
            type: "mrkdwn",
            text: format_kpt_item_content(item, index + 1)
          }
        }
      end
    end

    # Try項目の詳細
    if try_items.any?
      blocks << {
        type: "section",
        text: {
          type: "mrkdwn",
          text: "*🚀 Try（試してみたいこと）:*"
        }
      }
      
      try_items.each_with_index do |item, index|
        blocks << {
          type: "section",
          text: {
            type: "mrkdwn",
            text: format_kpt_item_content(item, index + 1)
          }
        }
      end
    end

    # タグがある場合
    if kpt_session.tags.any?
      blocks << {
        type: "section",
        text: {
          type: "mrkdwn",
          text: "*🏷️ タグ:*\n#{kpt_session.tags.map { |tag| "`#{tag}`" }.join(' ')}"
        }
      }
    end

    # フッター（アクション）
    blocks << {
      type: "actions",
      elements: [
        {
          type: "button",
          text: {
            type: "plain_text",
            text: "📊 詳細を見る"
          },
          style: "primary",
          url: (ENV['FRONTEND_URL'] || 'http://localhost:3000').chomp('/') + "/dashboard/kpt/#{kpt_session.id}"
        }
      ]
    }

    {
      text: "🎉 新しいKPTセッションが作成されました！",
      blocks: blocks
    }
  end

  def format_kpt_item_content(item, index)
    content = "#{index}. #{item.content}"
    
    # 感情スコアがある場合
    if item.emotion_score.present?
      emotion_emoji = case item.emotion_score
                     when 1..2 then '😢'
                     when 3..4 then '😐'
                     when 5..6 then '🙂'
                     when 7..8 then '😊'
                     when 9..10 then '😄'
                     else ''
                     end
      content += " #{emotion_emoji}"
    end

    # 影響度スコアがある場合
    if item.impact_score.present?
      impact_emoji = case item.impact_score
                    when 1..2 then '📉'
                    when 3..4 then '➡️'
                    when 5..6 then '📈'
                    when 7..8 then '🚀'
                    when 9..10 then '💥'
                    else ''
                    end
      content += " #{impact_emoji}"
    end

    # 期限がある場合
    if item.due_date.present?
      content += "\n   📅 期限: #{item.due_date.strftime('%Y年%m月%d日')}"
    end

    # 担当者がいる場合
    if item.assigned_to.present?
      content += "\n   👤 担当: #{item.assigned_to}"
    end

    # メモがある場合
    if item.notes.present?
      content += "\n   📝 メモ: #{item.notes}"
    end

    # タグがある場合
    if item.tags.any?
      content += "\n   🏷️ タグ: #{item.tags.map { |tag| "`#{tag}`" }.join(' ')}"
    end

    content
  end
end 