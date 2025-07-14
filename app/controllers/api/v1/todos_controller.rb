require "openai"

class Api::V1::TodosController < ApplicationController
  def suggest
    prompt = create_todo_prompt(params)

    begin
      client = OpenAI::Client.new(access_token: ENV["OPENAI_API_KEY"], request_timeout: 120)
      response = client.chat(
        parameters: {
          model: "gpt-4o",
          messages: [
            { role: "system", content: "あなたは優秀なタスクマネージャーです。" },
            { role: "user", content: prompt }
          ],
          temperature: 0.7
        }
      )

      content = response.dig("choices", 0, "message", "content")
      json_match = content.match(/```json\s*(.*?)\s*```/m)
      json_str = json_match ? json_match[1] : content.to_s.strip

      suggestion = JSON.parse(json_str)

      # Save each suggested Todo to the database
      suggestion.each do |todo_data|
        todo = current_user.todos.build(
          title: todo_data["title"],
          description: todo_data["description"],
          deadline: todo_data["deadline"],
          priority: todo_data["priority"],
          status: todo_data["status"]
        )

        unless todo.save
          render json: { errors: todo.errors.full_messages }, status: :unprocessable_entity
          return
        end
      end

      render json: suggestion, status: :ok
    rescue JSON::ParserError => e
      render json: { errors: [ "AIからの応答を解析できませんでした。", e.message ] }, status: :internal_server_error
    rescue => e
      render json: { errors: [ "予期せぬエラーが発生しました。", e.message ] }, status: :internal_server_error
    end
  end

  def create
    todo = current_user.todos.build(todo_params)

    if todo.save
      render json: todo, status: :created
    else
      render json: { errors: todo.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def index
    todos = current_user.todos
    render json: todos, status: :ok
  end

  def show
    todo = current_user.todos.find(params[:id])
    render json: todo, status: :ok
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Todo not found' }, status: :not_found
  end

  def update
    todo = current_user.todos.find(params[:id])
    if todo.update(status: params[:todo][:status])
      render json: todo, status: :ok
    else
      render json: { errors: todo.errors.full_messages }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Todo not found' }, status: :not_found
  end

  private

  def create_todo_prompt(prompt_params)
    <<~PROMPT
      あなたはタスクマネージャーです。以下のKPT情報をもとに、Todoの提案を日本語で行ってください。

      - Keep: #{prompt_params[:todo][:keep]}
      - Problem: #{prompt_params[:todo][:problem]}
      - Try: #{prompt_params[:todo][:try]}

      **Todoの作成ルール**:
      1. 各Todoは具体的で測定可能にする
      2. 現実的に実行可能な範囲で提案する

      出力フォーマットは以下のJSON形式で返してください。
      [
        {
          "title": "Todoタイトル",
          "description": "Todoの詳細説明",
          "deadline": "YYYY-MM-DD",
          "priority": "高",
          "status": "open"
        }
      ]
    PROMPT
  end

  def todo_params
    params.require(:todo).permit(:title, :description, :deadline, :priority, :status)
  end
end
