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
# - POST /api/v1/kpt_sessions/:id/complete セッション完了
# - POST /api/v1/kpt_sessions/:id/save_template テンプレート保存
class Api::V1::KptSessionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_kpt_session, only: [:show, :update, :destroy, :complete, :save_template]

  # セッション一覧を取得
  # @route GET /api/v1/kpt_sessions
  # @param [String] status ステータスフィルター
  # @param [String] tag タグフィルター
  # @param [String] session_date セッション日付フィルター（YYYY-MM-DD形式）
  # @param [Integer] page ページ番号
  # @param [Integer] per_page 1ページあたりの件数
  # @response [JSON] セッション一覧
  def index
    begin
      sessions = current_user.kpt_sessions.includes(:kpt_items)

      # フィルター適用
      sessions = sessions.by_status(params[:status]) if params[:status].present?
      sessions = sessions.with_tag(params[:tag]) if params[:tag].present?
      sessions = sessions.where(session_date: params[:session_date]) if params[:session_date].present?
      sessions = sessions.templates if params[:templates] == 'true'
      sessions = sessions.not_templates if params[:templates] == 'false'

      # ソート（日付指定がある場合は作成日時順、そうでなければ最新順）
      if params[:session_date].present?
        sessions = sessions.order(:created_at)
      else
        sessions = sessions.recent
      end

      # ページネーション
      page = params[:page]&.to_i || 1
      per_page = [params[:per_page]&.to_i || 20, 100].min

      total_count = sessions.count
      sessions = sessions.offset((page - 1) * per_page).limit(per_page)

      # データ整形
      sessions_data = sessions.map { |session| format_session_summary(session) }

      render json: {
        success: true,
        data: {
          sessions: sessions_data,
          pagination: {
            current_page: page,
            per_page: per_page,
            total_pages: (total_count.to_f / per_page).ceil,
            total_count: total_count
          }
        },
        message: 'セッション一覧を取得しました'
      }, status: :ok
    rescue StandardError => e
      render_error(error: 'セッション一覧の取得中にエラーが発生しました', status: :internal_server_error)
    end
  end

  # セッション詳細を取得
  # @route GET /api/v1/kpt_sessions/:id
  # @response [JSON] セッション詳細
  def show
    begin
      session_data = format_session_detail(@kpt_session)

      render json: {
        success: true,
        data: session_data,
        message: 'セッション詳細を取得しました'
      }, status: :ok
    rescue StandardError => e
      render_error(error: 'セッション詳細の取得中にエラーが発生しました', status: :internal_server_error)
    end
  end

  # セッションを作成
  # @route POST /api/v1/kpt_sessions
  # @param [Hash] session セッションデータ
  # @response [JSON] 作成されたセッション
  def create
    begin
      @kpt_session = current_user.kpt_sessions.build(session_params)

      if @kpt_session.save
        session_data = format_session_detail(@kpt_session)

        render json: {
          success: true,
          data: session_data,
          message: 'セッションを作成しました'
        }, status: :created
      else
        render json: {
          success: false,
          error: 'セッションの作成に失敗しました',
          details: @kpt_session.errors.full_messages
        }, status: :unprocessable_entity
      end
    rescue StandardError => e
      render_error(error: 'セッションの作成中にエラーが発生しました', status: :internal_server_error)
    end
  end

  # セッションを更新
  # @route PUT /api/v1/kpt_sessions/:id
  # @param [Hash] session セッションデータ
  # @response [JSON] 更新されたセッション
  def update
    begin
      if @kpt_session.update(session_params)
        session_data = format_session_detail(@kpt_session)

        render json: {
          success: true,
          data: session_data,
          message: 'セッションを更新しました'
        }, status: :ok
      else
        render json: {
          success: false,
          error: 'セッションの更新に失敗しました',
          details: @kpt_session.errors.full_messages
        }, status: :unprocessable_entity
      end
    rescue StandardError => e
      render_error(error: 'セッションの更新中にエラーが発生しました', status: :internal_server_error)
    end
  end

  # セッションを削除
  # @route DELETE /api/v1/kpt_sessions/:id
  # @response [JSON] 削除結果
  def destroy
    begin
      if @kpt_session.destroy
        render json: {
          success: true,
          message: 'セッションを削除しました'
        }, status: :ok
      else
        render json: {
          success: false,
          error: 'セッションの削除に失敗しました',
          details: @kpt_session.errors.full_messages
        }, status: :unprocessable_entity
      end
    rescue StandardError => e
      render_error(error: 'セッションの削除中にエラーが発生しました', status: :internal_server_error)
    end
  end

  # セッションを完了
  # @route POST /api/v1/kpt_sessions/:id/complete
  # @response [JSON] 完了結果
  def complete
    begin
      if @kpt_session.update(status: 'completed')
        session_data = format_session_detail(@kpt_session)

        render json: {
          success: true,
          data: session_data,
          message: 'セッションを完了しました'
        }, status: :ok
      else
        render json: {
          success: false,
          error: 'セッションの完了に失敗しました',
          details: @kpt_session.errors.full_messages
        }, status: :unprocessable_entity
      end
    rescue StandardError => e
      render_error(error: 'セッション完了処理中にエラーが発生しました', status: :internal_server_error)
    end
  end

  # セッションをテンプレートとして保存
  # @route POST /api/v1/kpt_sessions/:id/save_template
  # @param [String] template_name テンプレート名
  # @response [JSON] 保存されたテンプレート
  def save_template
    begin
      template_name = params[:template_name]
      
      if template_name.blank?
        render json: {
          success: false,
          error: 'テンプレート名を入力してください'
        }, status: :unprocessable_entity
        return
      end

      template = @kpt_session.save_as_template(template_name)

      if template.persisted?
        template_data = format_session_detail(template)

        render json: {
          success: true,
          data: template_data,
          message: 'テンプレートとして保存しました'
        }, status: :created
      else
        render json: {
          success: false,
          error: 'テンプレートの保存に失敗しました',
          details: template.errors.full_messages
        }, status: :unprocessable_entity
      end
    rescue StandardError => e
      render_error(error: 'テンプレート保存中にエラーが発生しました', status: :internal_server_error)
    end
  end

  # セッション統計を取得
  # @route GET /api/v1/kpt_sessions/stats
  # @param [Date] start_date 開始日
  # @param [Date] end_date 終了日
  # @response [JSON] セッション統計
  def stats
    begin
      start_date = params[:start_date]&.to_date || 30.days.ago.to_date
      end_date = params[:end_date]&.to_date || Date.current

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
          items_per_session: sessions.joins(:kpt_items).count.to_f / [sessions.count, 1].max,
          completion_rate: calculate_session_completion_rate(sessions),
          days_to_complete: calculate_average_completion_time(sessions)
        }
      }

      render json: {
        success: true,
        data: stats_data,
        message: 'セッション統計を取得しました'
      }, status: :ok
    rescue StandardError => e
      render_error(error: '統計データの取得に失敗しました', status: :internal_server_error)
    end
  end

  private

  # KPTセッションを設定
  def set_kpt_session
    @kpt_session = current_user.kpt_sessions.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: {
      success: false,
      error: 'セッションが見つかりません'
    }, status: :not_found
  end

  # セッションパラメーターを許可
  def session_params
    params.require(:session).permit(
      :title, :description, :session_date, :status, :is_template, :template_name,
      tags: []
    )
  end

  # セッションサマリーを整形
  # @param [KptSession] session セッション
  # @return [Hash] 整形されたサマリーデータ
  def format_session_summary(session)
    {
      id: session.id,
      title: session.title,
      description: session.description,
      session_date: session.session_date,
      status: session.status,
      is_template: session.is_template,
      template_name: session.template_name,
      tags: session.tags,
      items_count: session.kpt_items_count,
      progress_rate: session.progress_rate,
      created_at: session.created_at,
      updated_at: session.updated_at,
      completed_at: session.completed_at
    }
  end

  # セッション詳細を整形
  # @param [KptSession] session セッション
  # @return [Hash] 整形された詳細データ
  def format_session_detail(session)
    {
      id: session.id,
      title: session.title,
      description: session.description,
      session_date: session.session_date,
      status: session.status,
      is_template: session.is_template,
      template_name: session.template_name,
      tags: session.tags,
      items_count: session.kpt_items_count,
      progress_rate: session.progress_rate,
      average_emotion_score: session.average_emotion_score,
      average_impact_score: session.average_impact_score,
      kpt_items: session.kpt_items.map { |item| format_kpt_item(item) },
      created_at: session.created_at,
      updated_at: session.updated_at,
      completed_at: session.completed_at
    }
  end

  # KPTアイテムを整形
  # @param [KptItem] item KPTアイテム
  # @return [Hash] 整形されたアイテムデータ
  def format_kpt_item(item)
    {
      id: item.id,
      type: item.type,
      content: item.content,
      priority: item.priority,
      status: item.status,
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

  def render_error(error:, status:)
    render json: {
      success: false,
      error: error
    }, status: status
  end
end 