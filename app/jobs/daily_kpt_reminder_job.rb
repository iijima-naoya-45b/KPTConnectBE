require 'slack-ruby-client'

class DailyKptReminderJob < ApplicationJob
  queue_as :default

  def perform
    # Slack通知が有効なユーザーを取得
    users_with_slack = User.where(slack_notification_enabled: true)
                          .where.not(slack_webhook_url: [nil, ''])
    
    users_with_slack.find_each do |user|
      send_reminder_to_user(user)
      sleep(0.5) # レート制限対策で少し待機
    end
  rescue => e
    # エラーは静かに処理
  end

  private

  def send_reminder_to_user(user)
    # 今日既にKPTセッションを作成している場合はスキップ
    today_sessions = user.kpt_sessions.where(session_date: Date.current)
    
    if today_sessions.exists?
      return
    end

    # Slack Bot Tokenが設定されていない場合はWebhookを使用
    if ENV['SLACK_BOT_TOKEN'].present?
      send_bot_reminder(user)
    elsif user.slack_webhook_url.present?
      send_webhook_reminder(user)
    end
  rescue => e
    # エラーは静かに処理
  end

  def send_bot_reminder(user)
    # Slackユーザー情報を取得（メールアドレスから）
    slack_user_id = get_slack_user_id_by_email(user.email)
    
    unless slack_user_id
      return
    end

    client = Slack::Web::Client.new(token: ENV['SLACK_BOT_TOKEN'])
    
    # 過去の統計を取得
    recent_stats = get_user_kpt_stats(user)
    
    message = {
      channel: slack_user_id,
      text: "🌅 今日のKPT振り返りの時間です！",
      blocks: build_reminder_blocks(user, recent_stats)
    }
    
    response = client.chat_postMessage(message)
  rescue => e
    # エラーは静かに処理
  end

  def send_webhook_reminder(user)
    # Webhookでリマインダーを送信
    uri = URI(user.slack_webhook_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 10
    http.read_timeout = 10

    recent_stats = get_user_kpt_stats(user)

    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request.body = {
      text: "🌅 今日のKPT振り返りの時間です！",
      blocks: build_reminder_blocks(user, recent_stats)
    }.to_json

    response = http.request(request)
  rescue => e
    # エラーは静かに処理
  end

  def get_slack_user_id_by_email(email)
    return nil unless ENV['SLACK_BOT_TOKEN'].present?
    
    client = Slack::Web::Client.new(token: ENV['SLACK_BOT_TOKEN'])
    response = client.users_lookupByEmail(email: email)
    response['user']['id']
  rescue => e
    nil
  end

  def get_user_kpt_stats(user)
    # 過去7日間の統計
    seven_days_ago = 7.days.ago.to_date
    recent_sessions = user.kpt_sessions.where(session_date: seven_days_ago..Date.current)
    
    {
      sessions_this_week: recent_sessions.count,
      total_items_this_week: recent_sessions.joins(:kpt_items).count,
      last_session_date: user.kpt_sessions.maximum(:session_date),
      streak_days: calculate_streak_days(user)
    }
  end

  def calculate_streak_days(user)
    # 連続でKPTを行った日数を計算
    streak = 0
    date = Date.current - 1.day # 昨日から逆算
    
    30.times do # 最大30日分チェック
      if user.kpt_sessions.where(session_date: date).exists?
        streak += 1
        date = date - 1.day
      else
        break
      end
    end
    
    streak
  end

  def build_reminder_blocks(user, stats)
    blocks = [
      {
        type: 'section',
        text: {
          type: 'mrkdwn',
          text: "🌅 *おはようございます！今日のKPT振り返りの時間です*\n\n今日も1日の終わりに振り返りを行いましょう 💭"
        }
      }
    ]

    # 統計情報を追加
    if stats[:sessions_this_week] > 0 || stats[:streak_days] > 0
      stats_text = []
      
      if stats[:sessions_this_week] > 0
        stats_text << "📊 今週: #{stats[:sessions_this_week]}回実施"
      end
      
      if stats[:streak_days] > 0
        stats_text << "🔥 連続: #{stats[:streak_days]}日"
      end
      
      if stats[:last_session_date]
        days_since = (Date.current - stats[:last_session_date]).to_i
        if days_since == 1
          stats_text << "📅 前回: 昨日"
        elsif days_since > 1
          stats_text << "📅 前回: #{days_since}日前"
        end
      end

      if stats_text.any?
        blocks << {
          type: 'section',
          text: {
            type: 'mrkdwn',
            text: "#{stats_text.join(' | ')}"
          }
        }
      end
    end

    # 励ましメッセージ
    encouragement_messages = [
      "継続は力なり！今日も頑張りましょう 💪",
      "小さな積み重ねが大きな成長につながります 🌱",
      "振り返りは自己成長の第一歩です 📈",
      "今日の気づきが明日の改善につながります ✨",
      "習慣化への道のり、一緒に歩んでいきましょう 🚶‍♂️"
    ]
    
    encouragement = encouragement_messages.sample

    blocks << {
      type: 'section',
      text: {
        type: 'mrkdwn',
        text: encouragement
      }
    }

    # アクションボタン
    blocks << {
      type: 'actions',
      elements: [
        {
          type: 'button',
          text: {
            type: 'plain_text',
            text: '📝 KPTを作成'
          },
          style: 'primary',
          value: 'create_kpt'
        },
        {
          type: 'button',
          text: {
            type: 'plain_text',
            text: '📊 ダッシュボード'
          },
          url: "#{ENV['FRONTEND_URL'] || 'http://localhost:3000'}/dashboard"
        }
      ]
    }

    # Tips（時々表示）
    if rand(3) == 0 # 33%の確率でTipsを表示
      tips = [
        "💡 *Tip*: Keepは小さな成功も記録しましょう！",
        "💡 *Tip*: Problemは責める対象ではなく、改善の機会です",
        "💡 *Tip*: Tryは具体的で実行可能なアクションにしましょう",
        "💡 *Tip*: 3つのカテゴリーをバランス良く記録することが大切です",
        "💡 *Tip*: 感情も一緒に記録すると、より深い振り返りができます"
      ]
      
      blocks << {
        type: 'context',
        elements: [
          {
            type: 'mrkdwn',
            text: tips.sample
          }
        ]
      }
    end

    blocks
  end
end 