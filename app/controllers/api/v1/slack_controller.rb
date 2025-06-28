require 'slack-ruby-client'

class Api::V1::SlackController < ApplicationController
  before_action :verify_slack_request

  # POST /api/v1/slack/commands
  # Slash Command: /kpt を処理
  def commands
    case params[:command]
    when '/kpt'
      handle_kpt_command
    else
      render json: { text: "未対応のコマンドです。" }, status: :ok
    end
  rescue => e
    render json: { text: "エラーが発生しました。しばらく待ってから再度お試しください。" }, status: :ok
  end

  # POST /api/v1/slack/interactive
  # Interactive Components（モーダル送信など）を処理
  def interactive
    payload = JSON.parse(params[:payload])

    case payload['type']
    when 'view_submission'
      handle_modal_submission(payload)
    when 'block_actions'
      handle_block_actions(payload)
    else
      render json: {}, status: :ok
    end
  rescue => e
    render json: {}, status: :ok
  end

  private

  def handle_kpt_command
    user_email = params[:user_email]
    user = User.find_by(email: user_email)
    
    unless user
      render json: { 
        text: "申し訳ございません。あなたのSlackアカウント（#{user_email}）に対応するユーザーが見つかりませんでした。\n管理者にお問い合わせください。" 
      }, status: :ok
      return
    end

    # モーダルを開く
    trigger_id = params[:trigger_id]
    open_kpt_modal(trigger_id, user)
    
    # 即座に応答（モーダル表示の確認）
    render json: {}, status: :ok
  end

  def open_kpt_modal(trigger_id, user)
    client = Slack::Web::Client.new(token: ENV['SLACK_BOT_TOKEN'])
    
    modal_view = {
      type: 'modal',
      callback_id: 'kpt_submission',
      title: {
        type: 'plain_text',
        text: 'KPT振り返り作成'
      },
      submit: {
        type: 'plain_text',
        text: '作成'
      },
      close: {
        type: 'plain_text',
        text: 'キャンセル'
      },
      private_metadata: user.id.to_s, # ユーザーIDを埋め込み
      blocks: [
        {
          type: 'input',
          block_id: 'title_block',
          element: {
            type: 'plain_text_input',
            action_id: 'title_input',
            placeholder: {
              type: 'plain_text',
              text: '例: 2025年1月27日の振り返り'
            }
          },
          label: {
            type: 'plain_text',
            text: 'セッション名'
          }
        },
        {
          type: 'input',
          block_id: 'description_block',
          element: {
            type: 'plain_text_input',
            action_id: 'description_input',
            multiline: true,
            placeholder: {
              type: 'plain_text',
              text: '今日の振り返りについて簡単に説明してください'
            }
          },
          label: {
            type: 'plain_text',
            text: 'セッション説明'
          },
          optional: true
        },
        {
          type: 'input',
          block_id: 'keep_block',
          element: {
            type: 'plain_text_input',
            action_id: 'keep_input',
            multiline: true,
            placeholder: {
              type: 'plain_text',
              text: '継続したいことを1行ずつ入力してください\n例:\n・チーム内でのコミュニケーションが活発だった\n・計画通りにタスクを進められた'
            }
          },
          label: {
            type: 'plain_text',
            text: '✅ Keep（継続したいこと）'
          },
          optional: true
        },
        {
          type: 'input',
          block_id: 'problem_block',
          element: {
            type: 'plain_text_input',
            action_id: 'problem_input',
            multiline: true,
            placeholder: {
              type: 'plain_text',
              text: '改善したいことを1行ずつ入力してください\n例:\n・会議の時間が長すぎた\n・ドキュメント作成に時間がかかった'
            }
          },
          label: {
            type: 'plain_text',
            text: '⚠️ Problem（改善したいこと）'
          },
          optional: true
        },
        {
          type: 'input',
          block_id: 'try_block',
          element: {
            type: 'plain_text_input',
            action_id: 'try_input',
            multiline: true,
            placeholder: {
              type: 'plain_text',
              text: '試してみたいことを1行ずつ入力してください\n例:\n・会議アジェンダを事前に共有する\n・テンプレートを活用してドキュメント作成を効率化する'
            }
          },
          label: {
            type: 'plain_text',
            text: '🚀 Try（試してみたいこと）'
          },
          optional: true
        }
      ]
    }

    response = client.views_open(
      trigger_id: trigger_id,
      view: modal_view
    )
  rescue => e
    # エラーは静かに処理
  end

  def handle_modal_submission(payload)
    user_id = payload['view']['private_metadata'].to_i
    user = User.find_by(id: user_id)
    
    unless user
      render json: {}, status: :ok
      return
    end

    # モーダルの入力値を取得
    values = payload['view']['state']['values']
    
    title = values.dig('title_block', 'title_input', 'value') || "#{Date.current.strftime('%Y年%m月%d日')}の振り返り"
    description = values.dig('description_block', 'description_input', 'value') || ""
    keep_text = values.dig('keep_block', 'keep_input', 'value') || ""
    problem_text = values.dig('problem_block', 'problem_input', 'value') || ""
    try_text = values.dig('try_block', 'try_input', 'value') || ""

    # KPTセッションを作成
    kpt_session = user.kpt_sessions.build(
      title: title,
      description: description,
      session_date: Date.current
    )

    if kpt_session.save
      # KPT項目を作成
      create_kpt_items(kpt_session, keep_text, 'keep')
      create_kpt_items(kpt_session, problem_text, 'problem')
      create_kpt_items(kpt_session, try_text, 'try')

      # 成功メッセージをSlackに送信
      send_success_message(payload['user']['id'], kpt_session)
    else
      send_error_message(payload['user']['id'])
    end

    render json: {}, status: :ok
  end

  def create_kpt_items(kpt_session, text, type)
    return if text.blank?
    
    # 1行ずつ分割してKPT項目を作成
    text.split("\n").each do |line|
      content = line.strip.gsub(/^[・•\-\*\+]\s*/, '') # 箇条書き記号を除去
      next if content.blank?
      
      kpt_session.kpt_items.create!(
        type: type,
        content: content
      )
    end
  end

  def send_success_message(slack_user_id, kpt_session)
    client = Slack::Web::Client.new(token: ENV['SLACK_BOT_TOKEN'])
    
    message = {
      channel: slack_user_id, # DMで送信
      text: "✅ KPTセッションを作成しました！",
      blocks: [
        {
          type: 'section',
          text: {
            type: 'mrkdwn',
            text: "✅ *KPTセッションを作成しました！*\n\n*📝 セッション名:* #{kpt_session.title}\n*📊 作成項目数:* #{kpt_session.kpt_items.count}件"
          }
        },
        {
          type: 'actions',
          elements: [
            {
              type: 'button',
              text: {
                type: 'plain_text',
                text: '詳細を確認'
              },
              style: 'primary',
              url: "#{ENV['FRONTEND_URL'] || 'http://localhost:3000'}/dashboard/kpt/#{kpt_session.id}"
            }
          ]
        }
      ]
    }
    
    client.chat_postMessage(message)
  rescue => e
    # エラーは静かに処理
  end

  def send_error_message(slack_user_id)
    client = Slack::Web::Client.new(token: ENV['SLACK_BOT_TOKEN'])
    
    client.chat_postMessage(
      channel: slack_user_id,
      text: "❌ KPTセッションの作成中にエラーが発生しました。しばらく待ってから再度お試しください。"
    )
  rescue => e
    # エラーは静かに処理
  end

  def handle_block_actions(payload)
    action = payload['actions']&.first
    
    case action&.dig('value')
    when 'create_kpt'
      # リマインダーの「KPTを作成」ボタンが押された場合
      user_email = payload['user']['username'] + '@' + ENV['SLACK_WORKSPACE_DOMAIN'] # 調整が必要
      user = User.find_by(email: user_email) || User.find_by(email: payload['user']['profile']['email'])
      
      if user
        trigger_id = payload['trigger_id']
        open_kpt_modal(trigger_id, user)
      else
        # ユーザーが見つからない場合のエラーメッセージ
        client = Slack::Web::Client.new(token: ENV['SLACK_BOT_TOKEN'])
        client.chat_postEphemeral(
          channel: payload['channel']['id'],
          user: payload['user']['id'],
          text: "申し訳ございません。あなたのアカウント情報が見つかりませんでした。管理者にお問い合わせください。"
        )
      end
    end
    
    render json: {}, status: :ok
  rescue => e
    render json: {}, status: :ok
  end

  def verify_slack_request
    # Slack署名検証（セキュリティのため）
    timestamp = request.headers['X-Slack-Request-Timestamp']
    signature = request.headers['X-Slack-Signature']
    
    unless timestamp && signature
      render json: { error: 'Unauthorized' }, status: :unauthorized
      return
    end

    # タイムスタンプが古すぎる場合は拒否（リプレイ攻撃防止）
    if Time.current.to_i - timestamp.to_i > 300 # 5分
      render json: { error: 'Unauthorized' }, status: :unauthorized
      return
    end

    # 署名検証
    slack_signing_secret = ENV['SLACK_SIGNING_SECRET']
    unless slack_signing_secret
      render json: { error: 'Configuration Error' }, status: :internal_server_error
      return
    end

    request_body = request.raw_post
    basestring = "v0:#{timestamp}:#{request_body}"
    expected_signature = "v0=#{OpenSSL::HMAC.hexdigest('SHA256', slack_signing_secret, basestring)}"

    unless signature == expected_signature
      render json: { error: 'Unauthorized' }, status: :unauthorized
      return
    end
  end
end 