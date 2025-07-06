class Api::V1::GithubController < ApplicationController
  before_action :require_github_token, only: [ :issues, :issue_detail ]

  def index
    issues = current_user.github_issues
    render json: { success: true, issues: issues }
  end
  
  # GET /api/v1/github/issues
  # @return [JSON] Issue一覧
  def issues
    repo = params[:repo]
    Rails.logger.info("Repo parameter: #{repo}")

    return render_error("GITHUB_REPO_URLが未設定です") unless repo

    url = "https://api.github.com/repos/#{repo}/issues?state=all&per_page=50"
    Rails.logger.info("GitHub API URL: #{url}")

    response = github_api_get(url)
    Rails.logger.info("GitHub API Response: #{response.inspect}")

    return render_error("GitHub API取得失敗") unless response&.is_a?(Array)

    # PRでないものだけ抽出
    issues = response.reject { |issue| issue.key?("pull_request") }
    issues = issues.map { |issue| format_issue(issue) }
    render json: { success: true, issues: issues }
  end

  # GET /api/v1/github/issues/:number
  # @return [JSON] Issue詳細＋コメント
  def issue_detail
    repo = params[:repo]
    return render_error("GITHUB_REPO_URLが未設定です") unless repo

    number = params[:number]
    issue_url = "https://api.github.com/repos/#{repo}/issues/#{number}"
    comments_url = "https://api.github.com/repos/#{repo}/issues/#{number}/comments"

    issue = github_api_get(issue_url)
    comments = github_api_get(comments_url)

    return render_error("GitHub API取得失敗") unless issue

    render json: {
      success: true,
      issue: format_issue(issue),
      comments: Array(comments).map { |c| format_comment(c) }
    }
  end

  # == Webhook受信エンドポイント ==
  #
  # GitHubのProject系イベント（project, project_card, project_column）を受信し、
  # 内容をログ出力＋今後のKPT/Taskマッピング用にパースします。
  #
  # @route POST /api/v1/github/webhook
  # @param [JSON] GitHub Webhookイベントペイロード
  # @return [200] 成功時はOK
  def webhook
    event_type = request.headers["X-GitHub-Event"]
    payload = JSON.parse(request.body.read)
    case event_type
    when "project"
      # Project作成・編集・削除イベント
      # TODO: KPT/Taskへのマッピング処理
    when "project_card"
      # Projectカード（Issue/PR/Note）作成・編集・移動・削除イベント
      # TODO: KPT/Taskへのマッピング処理
    when "project_column"
      # Projectカラム（To do, In progress, Done等）作成・編集・移動・削除イベント
      # TODO: KPT/Taskへのマッピング処理
    else
    end

    head :ok
  end

  def save_issues
    issues = params[:issues]
    issues.each do |issue|
      begin
        current_user.github_issues.create!(
          title: issue[:title],
          body: issue[:body],
          state: issue[:state]
        )
      rescue => e
        Rails.logger.error("Failed to save issue: #{issue.inspect}, Error: #{e.message}")
        render json: { success: false, error: "Failed to save issue: #{issue[:title]}, Error: #{e.message}" }, status: :internal_server_error
        return
      end
    end
    render json: { success: true }
  end

  # DELETE /api/v1/github/issues/:id
  def destroy
    issue = current_user.github_issues.find(params[:id])
    if issue.destroy
      render json: { success: true, message: "Issue deleted successfully" }
    else
      render json: { success: false, error: "Failed to delete issue" }, status: :unprocessable_entity
    end
  end

  private

  # OAuthトークン取得（セッションやDBから）
  def github_token
    # 例: session[:github_token] など
    session[:github_token]
  end

  def require_github_token
    # 公開リポジトリのみならスキップ可
    # head :unauthorized unless github_token
  end

  # GitHub API GET
  def github_api_get(url)
    headers = { "Accept" => "application/vnd.github+json" }
    headers["Authorization"] = "token #{github_token}" if github_token.present?
    res = Faraday.get(url, nil, headers)
    JSON.parse(res.body) if res.status == 200
  rescue => e
    nil
  end

  # FE向けに整形
  def format_issue(issue)
    {
      id: issue["id"],
      number: issue["number"],
      title: issue["title"],
      body: issue["body"],
      state: issue["state"],
      created_at: issue["created_at"],
      updated_at: issue["updated_at"],
      closed_at: issue["closed_at"],
      user: format_user(issue["user"]),
      labels: (issue["labels"] || []).map { |l| l["name"] },
      url: issue["html_url"]
    }
  end

  def format_comment(comment)
    {
      id: comment["id"],
      body: comment["body"],
      user: format_user(comment["user"]),
      created_at: comment["created_at"],
      updated_at: comment["updated_at"],
      url: comment["html_url"]
    }
  end

  def format_user(user)
    return nil unless user
    {
      login: user["login"],
      avatar_url: user["avatar_url"],
      html_url: user["html_url"]
    }
  end

  def render_error(msg)
    render json: { success: false, error: msg }, status: :bad_request
  end
end
