require 'openai'

class Api::V1::GoalsController < ApplicationController
    before_action :authenticate_user! # devise等を利
    before_action :set_goal, only: [:show, :update, :destroy, :update_action_plan_progress]
  
    # GET /api/v1/goals
    def index
      @goals = current_user.goals.order(created_at: :desc)
      render json: @goals
    end
  
    # GET /api/v1/goals/:id
    def show
      render json: @goal
    end
  
    # POST /api/v1/goals
    def create
      goal_p = goal_params
      goal_p[:action_plan] ||= [] # action_planがnilの場合に空配列をセット

      @goal = current_user.goals.build(goal_p)
      if @goal.save
        render json: @goal, status: :created
      else
        render json: { errors: @goal.errors.full_messages }, status: :unprocessable_entity
      end
    end
  
    # PATCH/PUT /api/v1/goals/:id
    def update
      if @goal.update(goal_params)
        render json: @goal
      else
        render json: { errors: @goal.errors.full_messages }, status: :unprocessable_entity
      end
    end
  
    # DELETE /api/v1/goals/:id
    def destroy
      @goal.destroy
      head :no_content
    end

    # PATCH /api/v1/goals/:id/action_plans/:action_id
    def update_action_plan_progress
      action_id = params[:action_id]
      progress = params[:progress].to_i
      
      if @goal.update_action_plan_progress(action_id, progress)
        render json: { 
          message: 'アクションプランの進捗が更新されました',
          goal: @goal,
          action_plan_progress: @goal.action_plan_overall_progress
        }
      else
        render json: { errors: ['アクションプランの更新に失敗しました'] }, status: :unprocessable_entity
      end
    end

    # POST /api/v1/goals/suggest
    def suggest
      prompt = create_prompt(params)
      
      begin
        client = OpenAI::Client.new(access_token: ENV['OPENAI_API_KEY'], request_timeout: 120)
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
        json_match = content.match(/```json\s*(.*?)\s*```/m)
        json_str = json_match ? json_match[1] : content.to_s.strip
        
        suggestion = JSON.parse(json_str)
        render json: suggestion, status: :ok
      rescue JSON::ParserError => e
        render json: { errors: ["AIからの応答を解析できませんでした。", e.message] }, status: :internal_server_error
      rescue => e
        render json: { errors: ["予期せぬエラーが発生しました。", e.message] }, status: :internal_server_error
      end
    end
      
    private
  
    def set_goal
      @goal = current_user.goals.find(params[:id])
    end
  
    def goal_params
      params.require(:goal).permit(
        :title, 
        :description, 
        :deadline, 
        :progress,
        :status,
        :progress_check,
        :created_by_ai,
        action_plan: []
      )
    end

    def create_prompt(prompt_params)
      <<~PROMPT
        あなたはキャリアコーチです。以下の情報をもとに、学習目標のタイトルと詳細説明、アクションプラン、進捗管理方法を日本語で提案してください。

        **重要**: 設定された期日（#{prompt_params[:deadline]}）内で完了できる現実的なアクションプランを作成してください。工数オーバーにならないよう、優先順位をつけて実行可能な範囲で提案してください。

        - 職種: #{prompt_params[:role]}
        - 経験年数: #{prompt_params[:experience]}
        - 学びたいこと: #{prompt_params[:wantToLearn]}
        - 達成したいこと: #{prompt_params[:wantToAchieve]}
        - 希望期日: #{prompt_params[:deadline]}
        - 得意分野: #{prompt_params[:strength]}
        - 苦手分野: #{prompt_params[:weakness]}
        - 学習スタイル: #{prompt_params[:learningStyle]}
        - 週あたりの学習時間: #{prompt_params[:weeklyTime]}時間
        - 理想のキャリア像: #{prompt_params[:careerVision]}

        **アクションプランの作成ルール**:
        1. 設定された期日（#{prompt_params[:deadline]}）を絶対に超過しない
        2. 週#{prompt_params[:weeklyTime]}時間の学習時間を考慮する
        3. 優先順位の高いものから順番に配置する
        4. 各アクションは具体的で測定可能にする
        5. 現実的に実行可能な範囲で提案する
        6. 各アクションに期間を明記する

        出力フォーマットは以下のJSON形式で返してください。
        {
          "title": "目標タイトル",
          "description": "目標の詳細説明（何を、なぜ、いつまでに、どのレベルまで達成したいか。自身の強み・弱みやキャリアビジョンも踏まえて記載）",
          "action_plan": [
            "具体的なアクション1（期間と成果物を明記）",
            "具体的なアクション2（期間と成果物を明記）"
          ],
          "deadline": "#{prompt_params[:deadline]}",
          "progress_check": "進捗管理方法"
        }
      PROMPT
    end
end