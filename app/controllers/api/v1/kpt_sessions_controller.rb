# frozen_string_literal: true

# KPTセッションAPIコントローラー
#
# @description KPTセッションのCRUD操作を提供
# セッションの作成、更新、削除、テンプレート機能、
# セッション統計などの機能を実装
#
# @endpoints
# - GET /api/v1/kpt_sessions セッション一覧
# - GET /api/v1/kpt_sessions/:id セッション詳細
# - POST /api/v1/kpt_sessions セッション作成
# - PUT /api/v1/kpt_sessions/:id セッション更新
# - DELETE /api/v1/kpt_sessions/:id セッション削除
# - POST /api/v1/kpt_sessions/:id/save_template テンプレート保存
class Api::V1::KptSessionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_kpt_session, only: [ :show, :update, :destroy, :save_template ]

  # KPTセッション一覧を取得
  def index
    begin
      Rails.logger.info "KPTセッション一覧取得開始 - User ID: #{current_user.id}, パラメータ: #{params.inspect}"
      
      sessions = current_user.kpt_sessions.includes(:kpt_items)

      # フィルター適用
      sessions = sessions.with_tag(params[:tag]) if params[:tag].present?
      
      if params[:date].present?
        begin
          selected_date = Date.parse(params[:date])
          sessions = sessions.where(created_at: selected_date.all_day)
        rescue ArgumentError
          # 日付のパースに失敗した場合は何もしないか、エラーを返す
        end
      end

      if params[:start_date].present? && params[:end_date].present?
        sessions = sessions.by_date_range(params[:start_date], params[:end_date])
      elsif params[:session_date].present?
        sessions = sessions.where(session_date: params[:session_date])
      end

      sessions = sessions.templates if params[:templates] == "true"
      sessions = sessions.not_templates if params[:templates] == "false"

      # ソート（日付指定がある場合は作成日時順、そうでなければ最新順）
      if params[:date].present? || params[:session_date].present? || (params[:start_date].present? && params[:end_date].present?)
        sessions = sessions.order(:created_at)
      else
        sessions = sessions.recent
      end

      # ページネーション
      if params[:start_date].blank? && params[:end_date].blank?
      page = params[:page]&.to_i || 1
        per_page = [params[:per_page]&.to_i || 20, 100].min
      total_count = sessions.count
      sessions = sessions.offset((page - 1) * per_page).limit(per_page)
        pagination = {
          current_page: page,
          per_page: per_page,
          total_pages: (total_count.to_f / per_page).ceil,
          total_count: total_count
        }
      else
        total_count = sessions.count
        pagination = {
          current_page: 1,
          per_page: total_count,
          total_pages: 1,
          total_count: total_count
        }
      end

      # データ整形
      sessions_data = sessions.map { |session| format_session_summary(session) }

      Rails.logger.info "KPTセッション一覧取得完了 - 取得件数: #{sessions_data.length}, 総件数: #{total_count}"

      render json: {
        success: true,
        data: {
          sessions: sessions_data,
          pagination: pagination
        },
        message: "セッション一覧を取得しました"
      }, status: :ok
    rescue StandardError => e
      Rails.logger.error "KPTセッション一覧取得エラー - User ID: #{current_user.id}, Error: #{e.message}, Backtrace: #{e.backtrace.first(5).join(', ')}"
      render_error(error: "セッション一覧の取得中にエラーが発生しました: #{e.message}", status: :internal_server_error)
    end
  end

  # セッション詳細を取得
  def show
    begin
      Rails.logger.info "KPTセッション詳細取得開始 - Session ID: #{@kpt_session.id}, User ID: #{current_user.id}"
      
      session_data = format_session_detail(@kpt_session)

      Rails.logger.info "KPTセッション詳細取得完了 - Session ID: #{@kpt_session.id}"

      render json: {
        success: true,
        data: session_data,
        message: "セッション詳細を取得しました"
      }, status: :ok
    rescue StandardError => e
      Rails.logger.error "KPTセッション詳細取得エラー - Session ID: #{@kpt_session&.id}, User ID: #{current_user.id}, Error: #{e.message}, Backtrace: #{e.backtrace.first(5).join(', ')}"
      render_error(error: "セッション詳細の取得中にエラーが発生しました: #{e.message}", status: :internal_server_error)
    end
  end

  # セッションを作成
  def create
    begin
      Rails.logger.info "KPTセッション作成開始 - User ID: #{current_user.id}, パラメータ: #{params.inspect}"
      
      @kpt_session = current_user.kpt_sessions.build(session_params)

      if @kpt_session.save
        # パラメータからKPTアイテムを作成
        create_kpt_items_from_params

        session_data = format_session_detail(@kpt_session)

        # Slack通知を非同期で実行
        Rails.logger.info "KPTセッション作成: Slack通知ジョブを実行します - Session ID: #{@kpt_session.id}, User ID: #{current_user.id}"
        
        begin
          SlackNotificationJob.perform_later(@kpt_session.id)
          Rails.logger.info "KPTセッション作成: Slack通知ジョブを実行しました"
        rescue => e
          Rails.logger.error "KPTセッション作成: Slack通知ジョブの実行に失敗しました - Error: #{e.message}, Backtrace: #{e.backtrace.first(3).join(', ')}"
          # ジョブの失敗はセッション作成の成功を妨げない
        end

        Rails.logger.info "KPTセッション作成完了 - Session ID: #{@kpt_session.id}"

        render json: {
          success: true,
          data: session_data,
          message: "セッションを作成しました"
        }, status: :created
      else
        Rails.logger.warn "KPTセッション作成失敗 - User ID: #{current_user.id}, エラー: #{@kpt_session.errors.full_messages}"
        render json: {
          success: false,
          error: "セッションの作成に失敗しました",
          details: @kpt_session.errors.full_messages
        }, status: :unprocessable_entity
      end
    rescue ActionController::ParameterMissing => e
      Rails.logger.error "KPTセッション作成: パラメータ不足エラー - User ID: #{current_user.id}, Error: #{e.message}, 受信パラメータ: #{params.inspect}"
      render json: {
        success: false,
        error: "リクエストパラメータが不足しています",
        details: e.message,
        required_params: {
          session: {
            title: "セッションタイトル（必須）",
            session_date: "セッション日付（任意、デフォルト: 今日）",
            description: "セッション説明（任意）",
            status: "ステータス（任意、デフォルト: not_started、許可値: not_started, in_progress, completed, pending）",
            tags: "タグ（任意、配列）"
          }
        }
      }, status: :bad_request
    rescue StandardError => e
      Rails.logger.error "KPTセッション作成エラー - User ID: #{current_user.id}, Error: #{e.message}, Backtrace: #{e.backtrace.first(5).join(', ')}"
      render_error(error: "セッションの作成中にエラーが発生しました: #{e.message}", status: :internal_server_error)
    end
  end

  # セッションを更新
  def update
    begin
      Rails.logger.info "KPTセッション更新開始 - Session ID: #{@kpt_session.id}, User ID: #{current_user.id}, パラメータ: #{session_params.inspect}"
      
      if @kpt_session.update(session_params)
        session_data = format_session_detail(@kpt_session)

        Rails.logger.info "KPTセッション更新完了 - Session ID: #{@kpt_session.id}"

        render json: {
          success: true,
          data: session_data,
          message: "セッションを更新しました"
        }, status: :ok
      else
        Rails.logger.warn "KPTセッション更新失敗 - Session ID: #{@kpt_session.id}, エラー: #{@kpt_session.errors.full_messages}"
        render json: {
          success: false,
          error: "セッションの更新に失敗しました",
          details: @kpt_session.errors.full_messages
        }, status: :unprocessable_entity
      end
    rescue StandardError => e
      Rails.logger.error "KPTセッション更新エラー - Session ID: #{@kpt_session.id}, User ID: #{current_user.id}, Error: #{e.message}, Backtrace: #{e.backtrace.first(5).join(', ')}"
      render_error(error: "セッションの更新中にエラーが発生しました: #{e.message}", status: :internal_server_error)
    end
  end

  # セッションを削除
  def destroy
    begin
      Rails.logger.info "KPTセッション削除開始 - Session ID: #{@kpt_session.id}, User ID: #{current_user.id}"
      
      if @kpt_session.destroy
        Rails.logger.info "KPTセッション削除完了 - Session ID: #{@kpt_session.id}"

        render json: {
          success: true,
          message: "セッションを削除しました"
        }, status: :ok
      else
        Rails.logger.warn "KPTセッション削除失敗 - Session ID: #{@kpt_session.id}, エラー: #{@kpt_session.errors.full_messages}"
        render json: {
          success: false,
          error: "セッションの削除に失敗しました",
          details: @kpt_session.errors.full_messages
        }, status: :unprocessable_entity
      end
    rescue StandardError => e
      Rails.logger.error "KPTセッション削除エラー - Session ID: #{@kpt_session.id}, User ID: #{current_user.id}, Error: #{e.message}, Backtrace: #{e.backtrace.first(5).join(', ')}"
      render_error(error: "セッションの削除中にエラーが発生しました: #{e.message}", status: :internal_server_error)
    end
  end

  # セッションをテンプレートとして保存
  def save_template
    begin
      template_name = params[:template_name]
      Rails.logger.info "KPTセッションテンプレート保存開始 - Session ID: #{@kpt_session.id}, User ID: #{current_user.id}, テンプレート名: #{template_name}"

      if template_name.blank?
        Rails.logger.warn "KPTセッションテンプレート保存失敗 - テンプレート名が空です"
        render json: {
          success: false,
          error: "テンプレート名を入力してください"
        }, status: :unprocessable_entity
        return
      end

      template = @kpt_session.save_as_template(template_name)

      if template.persisted?
        template_data = format_session_detail(template)

        Rails.logger.info "KPTセッションテンプレート保存完了 - Template ID: #{template.id}"

        render json: {
          success: true,
          data: template_data,
          message: "テンプレートとして保存しました"
        }, status: :created
      else
        Rails.logger.warn "KPTセッションテンプレート保存失敗 - エラー: #{template.errors.full_messages}"
        render json: {
          success: false,
          error: "テンプレートの保存に失敗しました",
          details: template.errors.full_messages
        }, status: :unprocessable_entity
      end
    rescue StandardError => e
      Rails.logger.error "KPTセッションテンプレート保存エラー - Session ID: #{@kpt_session.id}, User ID: #{current_user.id}, Error: #{e.message}, Backtrace: #{e.backtrace.first(5).join(', ')}"
      render_error(error: "テンプレート保存中にエラーが発生しました: #{e.message}", status: :internal_server_error)
    end
  end

  # セッション統計を取得
  def stats
    begin
      start_date = params[:start_date]&.to_date || 30.days.ago.to_date
      end_date = params[:end_date]&.to_date || Date.current
      
      Rails.logger.info "KPTセッション統計取得開始 - User ID: #{current_user.id}, 期間: #{start_date} 〜 #{end_date}"

      sessions = current_user.kpt_sessions.by_date_range(start_date, end_date)

      stats_data = {
        period: {
          start_date: start_date,
          end_date: end_date
        },
        totals: {
          sessions_count: sessions.count,
          completed_sessions: sessions.completed.count,
          active_sessions: sessions.active.count,
          total_items: sessions.joins(:kpt_items).count,
          completed_items: sessions.joins(:kpt_items).merge(KptItem.completed).count
        },
        breakdown: {
          by_status: sessions.group(:status).count,
          by_month: sessions.group_by_month(:session_date).count,
          popular_tags: KptSession.popular_tags(current_user, 10)
        },
        averages: {
          items_per_session: sessions.joins(:kpt_items).count.to_f / [ sessions.count, 1 ].max,
          completion_rate: calculate_session_completion_rate(sessions),
          days_to_complete: calculate_average_completion_time(sessions)
        }
      }

      Rails.logger.info "KPTセッション統計取得完了 - User ID: #{current_user.id}, セッション数: #{stats_data[:totals][:sessions_count]}"

      render json: {
        success: true,
        data: stats_data,
        message: "セッション統計を取得しました"
      }, status: :ok
    rescue StandardError => e
      Rails.logger.error "KPTセッション統計取得エラー - User ID: #{current_user.id}, Error: #{e.message}, Backtrace: #{e.backtrace.first(5).join(', ')}"
      render_error(error: "統計データの取得に失敗しました: #{e.message}", status: :internal_server_error)
    end
  end

  private

  # KPTセッションをセット
  def set_kpt_session
    @kpt_session = current_user.kpt_sessions.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { success: false, error: "指定されたIDのKPTセッションが見つかりません" }, status: :not_found
  end

  # セッションパラメータを取得
  def session_params
    # パラメータの構造を確認し、適切なキーを選択
    session_data = if params[:session].present?
      params.require(:session)
    elsif params[:kpt_session].present?
      params.require(:kpt_session)
    else
      params
    end
    
    # パラメータを許可
    session_data.permit(
      :title,
      :description,
      :session_date,
      :is_template,
      :template_name,
      tags: [],
      keep: [:content, :emotion_score, :impact_score, { tags: [] }],
      problem: [:content, :emotion_score, :impact_score, { tags: [] }],
      try: [:content, :emotion_score, :impact_score, { tags: [] }]
    )
  end

  def format_session_summary(session)
    {
      id: session.id,
      title: session.title,
      description: session.description,
      session_date: session.session_date,
      tags: session.tags || [],
      items_count: session.kpt_items_count,
      progress_rate: session.progress_rate,
      created_at: session.created_at.iso8601,
      updated_at: session.updated_at.iso8601
    }
  end

  def format_session_detail(session)
    {
      id: session.id,
      title: session.title,
      description: session.description,
      session_date: session.session_date,
      tags: session.tags || [],
      kpt_items: session.kpt_items.map { |item| format_kpt_item(item) },
      insights: session.insights,
      created_at: session.created_at.iso8601,
      updated_at: session.updated_at.iso8601,
      progress_rate: session.progress_rate,
      average_emotion_score: session.average_emotion_score,
      average_impact_score: session.average_impact_score
    }
  end

  def format_kpt_item(item)
    {
      id: item.id,
      type: item.type,
      content: item.content,
      due_date: item.due_date,
      start_date: item.start_date,
      end_date: item.end_date,
      assigned_to: item.assigned_to,
      emotion_score: item.emotion_score,
      impact_score: item.impact_score,
      tags: item.tags,
      notes: item.notes,
      created_at: item.created_at,
      updated_at: item.updated_at,
      completed_at: item.completed_at
    }
  end

  # セッション完了率を計算
  # @param [ActiveRecord::Relation] sessions セッションクエリ
  # @return [Float] 完了率
  def calculate_session_completion_rate(sessions)
    total = sessions.count
    return 0.0 if total.zero?

    completed = sessions.completed.count
    (completed.to_f / total * 100).round(2)
  end

  # 平均完了時間を計算
  # @param [ActiveRecord::Relation] sessions セッションクエリ
  # @return [Float] 平均完了日数
  def calculate_average_completion_time(sessions)
    completed_sessions = sessions.completed.where.not(completed_at: nil)
    return 0.0 if completed_sessions.count.zero?

    total_days = completed_sessions.sum do |session|
      (session.completed_at.to_date - session.created_at.to_date).to_i
    end

    (total_days.to_f / completed_sessions.count).round(2)
  end

  # パラメータからKPTアイテムを作成
  def create_kpt_items_from_params
    return if @kpt_session.blank?

    items_to_create = []
    items_to_create << { type: "keep", content: params[:keep] } if params[:keep].present?
    items_to_create << { type: "problem", content: params[:problem] } if params[:problem].present?
    items_to_create << { type: "try", content: params[:try] } if params[:try].present?

    if items_to_create.any?
      @kpt_session.kpt_items.create(items_to_create)
      @kpt_session.reload
      Rails.logger.info "パラメータからKPTアイテムを作成しました - Session ID: #{@kpt_session.id}, 作成数: #{items_to_create.count}"
    end
  end

  def render_error(error:, status:)
    render json: {
      success: false,
      error: error
    }, status: status
  end
end
