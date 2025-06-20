require 'openai'

class Api::V1::GoalsController < ApplicationController
    before_action :authenticate_user! # devise等を利用の場合
    before_action :set_goal, only: [:show, :update, :destroy]
  
    # GET /api/v1/goals
    def index
      @goals = current_user.goals
      render json: @goals
    end
  
    # GET /api/v1/goals/:id
    def show
      render json: @goal
    end
  
    # POST /api/v1/goals
    def create
      @goal = current_user.goals.build(goal_params)
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

    def ai_suggest
      # ユーザー入力をもとにプロンプトを作成
      prompt = <<~PROMPT
        あなたはキャリアコーチです。以下の情報をもとに、学習目標のタイトルと詳細説明を日本語で提案してください。
        - 職種: #{params[:role]}
        - 経験年数: #{params[:experience]}
        - 学びたいこと: #{params[:wantToLearn]}
        - 達成したいこと: #{params[:wantToAchieve]}
        - 希望期日: #{params[:deadline]}
        - 得意分野: #{params[:strength]}
        - 苦手分野: #{params[:weakness]}
        - 学習スタイル: #{params[:learningStyle]}
        - 週あたりの学習時間: #{params[:weeklyTime]}
        - 理想のキャリア像: #{params[:careerVision]}
        出力フォーマットは以下のJSON形式で返してください。
        {
          "title": "目標タイトル",
          "description": "目標の詳細説明"
        }
      PROMPT

      # OpenAI API呼び出し
      client = OpenAI::Client.new(access_token: ENV['OPENAI_API_KEY'])
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

      # AIの返答からJSONを抽出
      suggestion = JSON.parse(response.dig("choices", 0, "message", "content")) rescue {}
      title = suggestion["title"] || "AI目標"
      description = suggestion["description"] || "AIによる説明が取得できませんでした。"

      goal = current_user.goals.build(
        title: title,
        description: description,
        deadline: params[:deadline],
        progress: 0
      )

      if goal.save
        render json: goal, status: :created
      else
        render json: { errors: goal.errors.full_messages }, status: :unprocessable_entity
      end
    rescue => e
      render json: { error: e.message }, status: :unprocessable_entity
    end
      
  
    private
  
    def set_goal
      @goal = current_user.goals.find(params[:id])
    end
  
    def goal_params
      params.require(:goal).permit(:title, :description, :deadline, :progress)
    end

    def ai_goal_insight_params
      params.require(:ai_goal_insight).permit(
        :title, :description, :mile_stone, :action_plan,
        :role, :experience, :wantToLearn, :wantToAchieve, :deadline,
        :strength, :weakness, :learningStyle, :weeklyTime, :careerVision
      )
    end
  end