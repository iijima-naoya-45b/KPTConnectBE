require "openai"

class SlackNotificationJob < ApplicationJob
  queue_as :default

  def perform(kpt_session_id)
    kpt_session = find_kpt_session(kpt_session_id)
    return unless kpt_session

    user = kpt_session.user
    return unless user

    return unless user.slack_notification_enabled? && user.slack_webhook_url.present?

    ai_reaction = generate_ai_reaction(kpt_session)
    send_slack_notification(user.slack_webhook_url, kpt_session, user, ai_reaction)
  end

  private

  def find_kpt_session(kpt_session_id)
    KptSession.find_by(id: kpt_session_id)
  end

  def send_slack_notification(webhook_url, kpt_session, user, ai_reaction)
    uri = URI(webhook_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 10
      http.read_timeout = 10

      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json"
      request.body = build_rich_slack_message(kpt_session, user, ai_reaction).to_json

    begin
      response = http.request(request)
    rescue => e
      # Handle errors silently
    end
  end

  def generate_ai_reaction(kpt_session)
    return get_fallback_message(kpt_session) unless ENV["OPENAI_API_KEY"].present?

    prompt = create_ai_reaction_prompt(kpt_session)
    client = OpenAI::Client.new(access_token: ENV["OPENAI_API_KEY"], request_timeout: 60)

    begin
      response = client.chat(
        parameters: {
          model: "gpt-4o-mini",
          messages: [
            { role: "system", content: "あなたは経験豊富なメンターです。ユーザーの1日の振り返りに対して、温かく建設的なフィードバックを提供してください。" },
            { role: "user", content: prompt }
          ],
          temperature: 0.7,
          max_tokens: 500
        }
      )

      content = response.dig("choices", 0, "message", "content")
      content.present? ? content.strip : get_fallback_message(kpt_session)
    rescue => e
      get_fallback_message(kpt_session)
    end
  end

  def get_fallback_message(kpt_session)
    keep_count = kpt_session.kpt_items.where(type: "keep").count
    problem_count = kpt_session.kpt_items.where(type: "problem").count
    try_count = kpt_session.kpt_items.where(type: "try").count
    total_count = keep_count + problem_count + try_count

    # KPTの内容に応じたフォールバックメッセージを生成
    if total_count == 0
      "今日も振り返りお疲れさまでした！ 🌟 明日も一歩ずつ前進していきましょう！"
    elsif keep_count > 0 && problem_count == 0 && try_count == 0
      "素晴らしいKeep項目ですね！ ✨ 良いことを継続する姿勢が成長につながります。明日も頑張りましょう！"
    elsif problem_count > 0 && try_count == 0
      "課題を発見できたのは素晴らしいですね！ 💡 次は解決策を考えて、Try項目も追加してみましょう。"
    elsif try_count > 0 && keep_count == 0 && problem_count == 0
      "新しい挑戦への意欲が素晴らしいです！ 🚀 ぜひ実行に移して、結果をKeepとして記録してくださいね。"
    elsif keep_count > 0 && try_count > 0
      "バランスの取れた振り返りですね！ 🎯 継続と挑戦の両立で、着実に成長されています。"
    else
      "今日も振り返りお疲れさまでした！ 📊 #{total_count}項目の気づきが明日への糧になりますね。継続していきましょう！"
    end
  end

  def create_ai_reaction_prompt(kpt_session)
    keep_items = kpt_session.kpt_items.where(type: "keep")
    problem_items = kpt_session.kpt_items.where(type: "problem")
    try_items = kpt_session.kpt_items.where(type: "try")

    session_date = kpt_session.session_date&.strftime("%Y年%m月%d日") || kpt_session.created_at.strftime("%Y年%m月%d日")

    prompt = <<~PROMPT
      以下は#{session_date}のKPT振り返りです。内容を分析して、温かく建設的なフィードバックを200文字以内で提供してください。

      【セッション】#{kpt_session.title}
      #{kpt_session.description.present? ? "【説明】#{kpt_session.description}" : ""}

      【Keep（継続したいこと）】#{keep_items.count}件
      #{keep_items.map { |item| "・#{item.content}" }.join("\n")}

      【Problem（改善したいこと）】#{problem_items.count}件
      #{problem_items.map { |item| "・#{item.content}" }.join("\n")}

      【Try（試してみたいこと）】#{try_items.count}件
      #{try_items.map { |item| "・#{item.content}" }.join("\n")}

      フィードバックのポイント：
      1. 良い点への評価と励まし
      2. バランスの取れた視点での建設的なアドバイス
      3. 明日への前向きなメッセージ
      4. 親しみやすい絵文字を適度に使用

      200文字以内で、温かく前向きなトーンでお願いします。
    PROMPT
  end

  def build_rich_slack_message(kpt_session, user, ai_reaction = nil)
    keep_items = kpt_session.kpt_items.where(type: "keep")
    problem_items = kpt_session.kpt_items.where(type: "problem")
    try_items = kpt_session.kpt_items.where(type: "try")

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
        text: {
          type: "mrkdwn",
          text: "*📝 セッション名:*\n#{kpt_session.title}"
        }
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

    # AIリアクションを最初に表示（目立つ位置に配置）
    if ai_reaction.present?
      blocks << {
        type: "section",
        text: {
          type: "mrkdwn",
          text: "*🤖 AIメンターからのメッセージ:*\n> #{ai_reaction}"
        }
      }
      # 区切り線を追加
      blocks << { type: "divider" }
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
          url: (ENV["FRONTEND_URL"] || "http://localhost:3000").chomp("/") + "/dashboard/kpt/#{kpt_session.id}"
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
      when 1..2 then "😢"
      when 3..4 then "😐"
      when 5..6 then "🙂"
      when 7..8 then "😊"
      when 9..10 then "😄"
      else ""
      end
      content += " #{emotion_emoji}"
    end

    # 影響度スコアがある場合
    if item.impact_score.present?
      impact_emoji = case item.impact_score
      when 1..2 then "📉"
      when 3..4 then "➡️"
      when 5..6 then "📈"
      when 7..8 then "🚀"
      when 9..10 then "💥"
      else ""
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
