require 'openai'

class Api::V1::AiGoalInsightsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_ai_goal_insight, only: [:show, :update, :destroy]
  skip_before_action :set_ai_goal_insight, only: [:create]

  # GET /api/v1/ai_goal_insights
  def index
    @ai_goal_insights = current_user.ai_goal_insights.order(created_at: :desc)
    render json: @ai_goal_insights.as_json(
      only: [:id, :title, :description, :milestone, :action_plan, :progress_check, :status, :progress, :created_at, :updated_at]
    )
  end

  # GET /api/v1/ai_goal_insights/:id
  def show
    render json: @ai_goal_insight
  end

  # POST /api/v1/ai_goal_insights
  # POST /api/v1/ai_goal_insights
def create
  permitted_params = ai_goal_insight_create_params

  # プロンプト生成（変更なし）
  prompt = <<~PROMPT
    あなたはキャリアコーチです。以下の情報をもとに、学習目標のタイトルと詳細説明、アクションプラン、期日、進捗管理方法を日本語で提案してください。

    - 職種: #{permitted_params[:role]}
    - 経験年数: #{permitted_params[:experience]}
    - 学びたいこと: #{permitted_params[:wantToLearn]}
    - 達成したいこと: #{permitted_params[:wantToAchieve]}
    - 希望期日: #{permitted_params[:milestone]}
    - 得意分野: #{permitted_params[:strength]}
    - 苦手分野: #{permitted_params[:weakness]}
    - 学習スタイル: #{permitted_params[:learningStyle]}
    - 週あたりの学習時間: #{permitted_params[:weeklyTime]}
    - 理想のキャリア像: #{permitted_params[:careerVision]}

    出力フォーマットは以下のJSON形式で返してください。
    {
      "title": "目標タイトル",
      "description": "目標の詳細説明（何を、なぜ、いつまでに、どのレベルまで達成したいか。自身の強み・弱みやキャリアビジョンも踏まえて記載）",
      "action_plan": [
        "具体的なアクション1",
        "具体的なアクション2"
      ],
      "milestone": "目標達成の期日（例：2025-08-15）",
      "progress_check": "進捗管理方法"
    }
  PROMPT

  # OpenAI API呼び出し（変更なし）
  client = OpenAI::Client.new(
    access_token: ENV['OPENAI_API_KEY'],
    request_timeout: 120
  )

  response = client.chat(
    parameters: {
      model: "gpt-4o",
      messages: [
        { role: "system", content: "あなたは優秀なキャリアコーチです。" },
        { role: "user", content: prompt }
      ],
      temperature: 0.7
    }
  )

  content = response.dig("choices", 0, "message", "content")
  Rails.logger.info("[AI Goal Insight] OpenAI API Raw Content: #{content.inspect}")

  # **ここから変更点**
  # マークダウンのコードブロックからJSON文字列を抽出する正規表現
  json_match = content.match(/```json\s*(.*?)\s*```/m)
  json_str = json_match ? json_match[1] : content.to_s.strip
  Rails.logger.info("[AI Goal Insight] Extracted JSON String: #{json_str.inspect}")
  # **ここまで変更点**

  suggestion = {}
  begin
    suggestion = JSON.parse(json_str)
    Rails.logger.info("[AI Goal Insight] Parsed Suggestion: #{suggestion.inspect}")
  rescue JSON::ParserError => e
    # JSONパースエラーの場合の処理を追加
    Rails.logger.error("[AI Goal Insight] JSON parse error: #{e.message}")
    Rails.logger.error("[AI Goal Insight] JSON parse error backtrace: #{e.backtrace.join("\n")}")
    render json: { errors: ["AIからの応答を解析できませんでした。", e.message] }, status: :internal_server_error and return
  rescue => e
    # その他の予期せぬエラーの場合の処理
    Rails.logger.error("[AI Goal Insight] An unexpected error occurred during JSON parsing: #{e.message}")
    Rails.logger.error("[AI Goal Insight] Unexpected error backtrace: #{e.backtrace.join("\n")}")
    render json: { errors: ["予期せぬエラーが発生しました。", e.message] }, status: :internal_server_error and return
  end

  # AI返却値セット（変更なし）
  title = suggestion["title"] || "AI目標"
  description = suggestion["description"] || "AIによる説明が取得できませんでした。"
  action_plan = suggestion["action_plan"] || []
  milestone = suggestion["milestone"] || permitted_params[:milestone]
  progress_check = suggestion["progress_check"] || ""

  @ai_goal_insight = current_user.ai_goal_insights.build(
    title: title,
    description: description,
    milestone: milestone,
    action_plan: action_plan,
    progress_check: progress_check,
    status: 'not_started', # initial status
    progress: 0 # initial progress
  )

  if @ai_goal_insight.save
    render json: {
      id: @ai_goal_insight.id,
      title: @ai_goal_insight.title,
      description: @ai_goal_insight.description,
      milestone: @ai_goal_insight.milestone,
      action_plan: @ai_goal_insight.action_plan,
      progress_check: @ai_goal_insight.progress_check,
      created_at: @ai_goal_insight.created_at,
      updated_at: @ai_goal_insight.updated_at
    }, status: :created
  else
    Rails.logger.error("[AI Goal Insight] 保存失敗エラー: #{@ai_goal_insight.errors.full_messages.inspect}")
    render json: { errors: @ai_goal_insight.errors.full_messages }, status: :unprocessable_entity
  end
end

  # PATCH/PUT /api/v1/ai_goal_insights/:id
  def update
    if @ai_goal_insight.update(ai_goal_insight_params)
      render json: @ai_goal_insight
    else
      render json: { errors: @ai_goal_insight.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/ai_goal_insights/:id
  def destroy
    @ai_goal_insight.destroy
    head :no_content
  end

  private

  def set_ai_goal_insight
    unless params[:id].present?
      Rails.logger.warn("set_ai_goal_insight called without ID in #{action_name} action. Skipping find.")
      return
    end
    @ai_goal_insight = current_user.ai_goal_insights.find(params[:id])
  end

  # Strong Parameters for create
  def ai_goal_insight_create_params
    params.require(:ai_goal_insight).permit(
      :role, :experience, :wantToLearn, :wantToAchieve,
      :strength, :weakness, :learningStyle,
      :weeklyTime, :careerVision,
      :title, :description, :milestone, :progress_check,
      action_plan: []
    )
  end

  # Strong Parameters for update
  def ai_goal_insight_params
    params.require(:ai_goal_insight).permit(
      :title, :description, :milestone, :progress_check, :status, :progress,
      action_plan: []
    )
  end
end
