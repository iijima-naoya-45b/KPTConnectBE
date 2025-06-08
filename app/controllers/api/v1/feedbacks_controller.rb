# frozen_string_literal: true

# フィードバックAPIコントローラー
#
# @description ユーザーからのフィードバック送信機能を提供するAPIコントローラー
# フロントエンドのFeedbackFormから送信されるフィードバックを処理
class Api::V1::FeedbacksController < ApplicationController
  before_action :require_login, only: [ :create ]
  before_action :set_feedback, only: [ :show ]
  before_action :require_admin, only: [ :index, :show, :update, :destroy ]

  # フィードバック一覧取得（管理者のみ）
  # GET /api/v1/feedbacks
  def index
    begin
      # パラメータ取得
      page = params[:page]&.to_i || 1
      limit = [ params[:limit]&.to_i || 20, 100 ].min
      status_filter = params[:status]
      type_filter = params[:type]
      priority_filter = params[:priority]
      search_query = params[:search]

      # ベースクエリ
      feedbacks_query = Feedback.includes(:user, :feedback_type, :feedback_priority)
                                .active

      # フィルタリング
      feedbacks_query = feedbacks_query.where(status: status_filter) if status_filter.present?

      if type_filter.present?
        feedbacks_query = feedbacks_query.joins(:feedback_type)
                                         .where(feedback_types: { key: type_filter })
      end

      if priority_filter.present?
        feedbacks_query = feedbacks_query.joins(:feedback_priority)
                                         .where(feedback_priorities: { key: priority_filter })
      end

      # 検索機能
      if search_query.present?
        feedbacks_query = feedbacks_query.where(
          "title ILIKE ? OR description ILIKE ? OR email ILIKE ?",
          "%#{search_query}%", "%#{search_query}%", "%#{search_query}%"
        )
      end

      # ページネーション
      offset = (page - 1) * limit
      feedbacks = feedbacks_query.order(created_at: :desc)
                                 .limit(limit)
                                 .offset(offset)

      # 総件数取得
      total_count = feedbacks_query.count

      # 統計情報取得
      statistics = Feedback.statistics

      render json: {
        success: true,
        data: {
          feedbacks: feedbacks.map { |feedback| feedback_data(feedback) },
          pagination: {
            current_page: page,
            per_page: limit,
            total_count: total_count,
            total_pages: (total_count.to_f / limit).ceil
          },
          statistics: statistics,
          filters: {
            types: FeedbackType.active.ordered.select(:id, :name, :key),
            priorities: FeedbackPriority.active.ordered.select(:id, :name, :key),
            statuses: Feedback::STATUSES
          }
        }
      }, status: :ok

    rescue StandardError => e

      render json: {
        success: false,
        message: "フィードバック一覧の取得に失敗しました",
        error: e.message
      }, status: :internal_server_error
    end
  end

  # フィードバック詳細取得（管理者のみ）
  # GET /api/v1/feedbacks/:id
  def show
    begin
      render json: {
        success: true,
        data: {
          feedback: feedback_detail_data(@feedback),
          related_feedbacks: related_feedbacks(@feedback)
        }
      }, status: :ok

    rescue StandardError => e

      render json: {
        success: false,
        message: "フィードバック詳細の取得に失敗しました",
        error: e.message
      }, status: :internal_server_error
    end
  end

  # フィードバック作成
  # POST /api/v1/feedbacks
  def create
    begin
      # パラメータ取得
      feedback_params_data = feedback_params

      # フィードバック種別の取得
      feedback_type = FeedbackType.find_by_key(feedback_params_data[:type])
      unless feedback_type
        return render json: {
          success: false,
          message: "無効なフィードバック種別です",
          errors: { type: [ "が無効です" ] }
        }, status: :unprocessable_entity
      end

      # フィードバック優先度の取得
      feedback_priority = FeedbackPriority.find_by_key(feedback_params_data[:priority])
      unless feedback_priority
        return render json: {
          success: false,
          message: "無効なフィードバック優先度です",
          errors: { priority: [ "が無効です" ] }
        }, status: :unprocessable_entity
      end

      # フィードバック作成
      feedback = current_user.feedbacks.build(
        feedback_type: feedback_type,
        feedback_priority: feedback_priority,
        title: feedback_params_data[:title],
        description: feedback_params_data[:description],
        email: feedback_params_data[:email],
        metadata: collect_metadata
      )

      if feedback.save
        # 成功レスポンス
        render json: {
          success: true,
          message: "フィードバックを送信しました。ご協力ありがとうございます。",
          data: {
            feedback: {
              id: feedback.id,
              title: feedback.title,
              type: feedback.feedback_type.name,
              priority: feedback.feedback_priority.name,
              created_at: feedback.created_at
            }
          }
        }, status: :created
      else
        # バリデーションエラー
        render json: {
          success: false,
          message: "フィードバックの送信に失敗しました",
          errors: feedback.errors.as_json
        }, status: :unprocessable_entity
      end

    rescue StandardError => e

      render json: {
        success: false,
        message: "フィードバックの送信に失敗しました",
        error: e.message
      }, status: :internal_server_error
    end
  end

  # フィードバック更新（管理者のみ）
  # PATCH/PUT /api/v1/feedbacks/:id
  def update
    begin
      update_params_data = update_params

      if @feedback.update(update_params_data)
        render json: {
          success: true,
          message: "フィードバックを更新しました",
          data: {
            feedback: feedback_detail_data(@feedback)
          }
        }, status: :ok
      else
        render json: {
          success: false,
          message: "フィードバックの更新に失敗しました",
          errors: @feedback.errors.as_json
        }, status: :unprocessable_entity
      end

    rescue StandardError => e

      render json: {
        success: false,
        message: "フィードバックの更新に失敗しました",
        error: e.message
      }, status: :internal_server_error
    end
  end

  # フィードバック削除（管理者のみ）
  # DELETE /api/v1/feedbacks/:id
  def destroy
    begin
      @feedback.update!(is_active: false)

      render json: {
        success: true,
        message: "フィードバックを削除しました"
      }, status: :ok

    rescue StandardError => e

      render json: {
        success: false,
        message: "フィードバックの削除に失敗しました",
        error: e.message
      }, status: :internal_server_error
    end
  end

  private

  # フィードバックオブジェクトを設定
  def set_feedback
    @feedback = Feedback.includes(:user, :feedback_type, :feedback_priority)
                        .active
                        .find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: {
      success: false,
      message: "フィードバックが見つかりません"
    }, status: :not_found
  end

  # 管理者権限チェック
  def require_admin
    unless current_user&.admin?
      render json: {
        success: false,
        message: "管理者権限が必要です"
      }, status: :forbidden
    end
  end

  # フィードバック作成用パラメータ
  def feedback_params
    params.require(:feedback).permit(:type, :title, :description, :priority, :email)
  end

  # フィードバック更新用パラメータ（管理者のみ）
  def update_params
    params.require(:feedback).permit(:status, :admin_notes)
  end

  # メタデータ収集
  def collect_metadata
    {
      user_agent: request.user_agent,
      ip_address: request.remote_ip,
      referer: request.referer,
      submitted_at: Time.current.iso8601
    }
  end

  # フィードバック基本データ
  def feedback_data(feedback)
    {
      id: feedback.id,
      title: feedback.display_title,
      description: feedback.display_description(150),
      type: {
        id: feedback.feedback_type.id,
        name: feedback.feedback_type.name,
        key: feedback.feedback_type.key,
        color_code: feedback.feedback_type.color_code,
        icon_name: feedback.feedback_type.icon_name
      },
      priority: {
        id: feedback.feedback_priority.id,
        name: feedback.feedback_priority.name,
        key: feedback.feedback_priority.key,
        level: feedback.feedback_priority.priority_level,
        color_code: feedback.feedback_priority.color_code,
        badge_class: feedback.feedback_priority.badge_class
      },
      user: {
        id: feedback.user.id,
        name: feedback.user.display_name,
        email: feedback.user.email,
        avatar_url: feedback.user.avatar_url
      },
      status: feedback.status,
      email: feedback.email,
      created_at: feedback.created_at,
      time_since_created: feedback.time_since_created,
      high_priority: feedback.high_priority?
    }
  end

  # フィードバック詳細データ
  def feedback_detail_data(feedback)
    data = feedback_data(feedback)
    data.merge({
      description: feedback.description, # 全文
      admin_notes: feedback.admin_notes,
      resolved_at: feedback.resolved_at,
      resolution_time: feedback.resolution_time,
      metadata: feedback.metadata
    })
  end

  # 関連フィードバック取得
  def related_feedbacks(feedback)
    Feedback.where(user: feedback.user)
            .where.not(id: feedback.id)
            .active
            .includes(:feedback_type, :feedback_priority)
            .order(created_at: :desc)
            .limit(5)
            .map { |f| feedback_data(f) }
  end
end
