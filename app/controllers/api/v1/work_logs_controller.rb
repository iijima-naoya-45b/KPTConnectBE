# frozen_string_literal: true

# 作業ログAPIコントローラー
#
# @description 作業ログのCRUD操作を提供
# 作業時間管理、生産性追跡、KPTセッションとの連携
#
# @endpoints
# - GET /api/v1/work_logs 作業ログ一覧
# - GET /api/v1/work_logs/:id 作業ログ詳細
# - POST /api/v1/work_logs 作業ログ作成
# - PUT /api/v1/work_logs/:id 作業ログ更新
# - DELETE /api/v1/work_logs/:id 作業ログ削除
# - POST /api/v1/work_logs/:id/complete 作業ログ完了
# - POST /api/v1/work_logs/:id/link_kpt KPTセッション連携
class Api::V1::WorkLogsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_work_log, only: [:show, :update, :destroy, :complete, :link_kpt, :unlink_kpt]

  # 作業ログ一覧を取得
  # @route GET /api/v1/work_logs
  # @param [String] category カテゴリフィルター
  # @param [String] project_name プロジェクト名フィルター
  # @param [String] status ステータスフィルター
  # @param [Date] date_from 開始日フィルター
  # @param [Date] date_to 終了日フィルター
  # @param [String] tag タグフィルター
  # @param [Integer] page ページ番号
  # @param [Integer] per_page 1ページあたりの件数
  # @response [JSON] 作業ログ一覧
  def index
    begin
      work_logs = current_user.work_logs.order(started_at: :desc)

      # フィルター適用
      work_logs = work_logs.where(category: params[:category]) if params[:category].present?
      work_logs = work_logs.where(project_name: params[:project_name]) if params[:project_name].present?
      work_logs = work_logs.where(status: params[:status]) if params[:status].present?
      work_logs = work_logs.where('started_at >= ?', params[:date_from]) if params[:date_from].present?
      work_logs = work_logs.where('started_at <= ?', params[:date_to]) if params[:date_to].present?
      work_logs = work_logs.where('? = ANY(tags)', params[:tag]) if params[:tag].present?

      # ページネーション
      page = params[:page]&.to_i || 1
      per_page = [params[:per_page]&.to_i || 20, 100].min

      total_count = work_logs.count
      work_logs = work_logs.offset((page - 1) * per_page).limit(per_page)

      # データ整形
      work_logs_data = work_logs.map { |log| format_work_log_summary(log) }

      render json: {
        success: true,
        data: {
          work_logs: work_logs_data,
          pagination: {
            current_page: page,
            per_page: per_page,
            total_pages: (total_count.to_f / per_page).ceil,
            total_count: total_count
          },
          summary: calculate_period_summary(work_logs)
        },
        message: '作業ログ一覧を取得しました'
      }, status: :ok
    rescue StandardError => e
      Rails.logger.error "Work logs index error: #{e.message}"
      render json: {
        success: false,
        error: '作業ログ一覧の取得に失敗しました',
        details: e.message
      }, status: :internal_server_error
    end
  end

  # 作業ログ詳細を取得
  # @route GET /api/v1/work_logs/:id
  # @response [JSON] 作業ログ詳細
  def show
    begin
      work_log_data = format_work_log_detail(@work_log)

      render json: {
        success: true,
        data: work_log_data,
        message: '作業ログ詳細を取得しました'
      }, status: :ok
    rescue StandardError => e
      Rails.logger.error "Work log show error: #{e.message}"
      render json: {
        success: false,
        error: '作業ログ詳細の取得に失敗しました',
        details: e.message
      }, status: :internal_server_error
    end
  end

  # 作業ログを作成
  # @route POST /api/v1/work_logs
  # @param [Hash] work_log 作業ログデータ
  # @response [JSON] 作成された作業ログ
  def create
    begin
      @work_log = current_user.work_logs.build(work_log_params)

      if @work_log.save
        work_log_data = format_work_log_detail(@work_log)

        render json: {
          success: true,
          data: work_log_data,
          message: '作業ログを作成しました'
        }, status: :created
      else
        render json: {
          success: false,
          error: '作業ログの作成に失敗しました',
          details: @work_log.errors.full_messages
        }, status: :unprocessable_entity
      end
    rescue StandardError => e
      Rails.logger.error "Work log create error: #{e.message}"
      render json: {
        success: false,
        error: '作業ログの作成中にエラーが発生しました',
        details: e.message
      }, status: :internal_server_error
    end
  end

  # 作業ログを更新
  # @route PUT /api/v1/work_logs/:id
  # @param [Hash] work_log 作業ログデータ
  # @response [JSON] 更新された作業ログ
  def update
    begin
      if @work_log.update(work_log_params)
        work_log_data = format_work_log_detail(@work_log)

        render json: {
          success: true,
          data: work_log_data,
          message: '作業ログを更新しました'
        }, status: :ok
      else
        render json: {
          success: false,
          error: '作業ログの更新に失敗しました',
          details: @work_log.errors.full_messages
        }, status: :unprocessable_entity
      end
    rescue StandardError => e
      Rails.logger.error "Work log update error: #{e.message}"
      render json: {
        success: false,
        error: '作業ログの更新中にエラーが発生しました',
        details: e.message
      }, status: :internal_server_error
    end
  end

  # 作業ログを削除
  # @route DELETE /api/v1/work_logs/:id
  # @response [JSON] 削除結果
  def destroy
    begin
      if @work_log.destroy
        render json: {
          success: true,
          message: '作業ログを削除しました'
        }, status: :ok
      else
        render json: {
          success: false,
          error: '作業ログの削除に失敗しました',
          details: @work_log.errors.full_messages
        }, status: :unprocessable_entity
      end
    rescue StandardError => e
      Rails.logger.error "Work log destroy error: #{e.message}"
      render json: {
        success: false,
        error: '作業ログの削除中にエラーが発生しました',
        details: e.message
      }, status: :internal_server_error
    end
  end

  # 作業ログを完了
  # @route POST /api/v1/work_logs/:id/complete
  # @param [DateTime] ended_at 終了時刻
  # @response [JSON] 完了結果
  def complete
    begin
      ended_at = params[:ended_at]&.to_datetime || Time.current

      if @work_log.update(status: 'completed', ended_at: ended_at)
        work_log_data = format_work_log_detail(@work_log)

        render json: {
          success: true,
          data: work_log_data,
          message: '作業ログを完了しました'
        }, status: :ok
      else
        render json: {
          success: false,
          error: '作業ログの完了に失敗しました',
          details: @work_log.errors.full_messages
        }, status: :unprocessable_entity
      end
    rescue StandardError => e
      Rails.logger.error "Work log complete error: #{e.message}"
      render json: {
        success: false,
        error: '作業ログ完了処理中にエラーが発生しました',
        details: e.message
      }, status: :internal_server_error
    end
  end

  # KPTセッションと連携
  # @route POST /api/v1/work_logs/:id/link_kpt
  # @param [UUID] kpt_session_id KPTセッションID
  # @param [Integer] relevance_score 関連度スコア
  # @param [String] notes 連携メモ
  # @response [JSON] 連携結果
  def link_kpt
    begin
      kpt_session = current_user.kpt_sessions.find(params[:kpt_session_id])
      relevance_score = params[:relevance_score]&.to_i || 3
      notes = params[:notes]

      link = @work_log.work_log_kpt_links.build(
        kpt_session: kpt_session,
        relevance_score: relevance_score,
        notes: notes
      )

      if link.save
        render json: {
          success: true,
          data: {
            link: format_kpt_link(link),
            work_log: format_work_log_detail(@work_log)
          },
          message: 'KPTセッションと連携しました'
        }, status: :created
      else
        render json: {
          success: false,
          error: 'KPTセッションとの連携に失敗しました',
          details: link.errors.full_messages
        }, status: :unprocessable_entity
      end
    rescue ActiveRecord::RecordNotFound
      render json: {
        success: false,
        error: 'KPTセッションが見つかりません'
      }, status: :not_found
    rescue StandardError => e
      Rails.logger.error "Work log link_kpt error: #{e.message}"
      render json: {
        success: false,
        error: 'KPTセッション連携中にエラーが発生しました',
        details: e.message
      }, status: :internal_server_error
    end
  end

  # KPTセッションとの連携を解除
  # @route DELETE /api/v1/work_logs/:id/link_kpt/:kpt_session_id
  # @response [JSON] 連携解除結果
  def unlink_kpt
    begin
      kpt_session = current_user.kpt_sessions.find(params[:kpt_session_id])
      link = @work_log.work_log_kpt_links.find_by(kpt_session: kpt_session)

      if link&.destroy
        render json: {
          success: true,
          message: 'KPTセッションとの連携を解除しました'
        }, status: :ok
      else
        render json: {
          success: false,
          error: '連携情報が見つかりません'
        }, status: :not_found
      end
    rescue ActiveRecord::RecordNotFound
      render json: {
        success: false,
        error: 'KPTセッションが見つかりません'
      }, status: :not_found
    rescue StandardError => e
      Rails.logger.error "Work log unlink_kpt error: #{e.message}"
      render json: {
        success: false,
        error: 'KPTセッション連携解除中にエラーが発生しました',
        details: e.message
      }, status: :internal_server_error
    end
  end

  # 作業ログ統計を取得
  # @route GET /api/v1/work_logs/stats
  # @param [Date] start_date 開始日
  # @param [Date] end_date 終了日
  # @response [JSON] 作業ログ統計
  def stats
    begin
      start_date = params[:start_date]&.to_date || 1.month.ago.to_date
      end_date = params[:end_date]&.to_date || Date.current

      work_logs = current_user.work_logs.where(started_at: start_date..end_date.end_of_day)

      stats_data = {
        period: {
          start_date: start_date,
          end_date: end_date
        },
        summary: {
          total_logs: work_logs.count,
          completed_logs: work_logs.where(status: 'completed').count,
          total_duration_minutes: work_logs.sum(:duration_minutes),
          billable_duration_minutes: work_logs.where(is_billable: true).sum(:duration_minutes)
        },
        averages: {
          mood_score: work_logs.where.not(mood_score: nil).average(:mood_score)&.round(2),
          productivity_score: work_logs.where.not(productivity_score: nil).average(:productivity_score)&.round(2),
          difficulty_score: work_logs.where.not(difficulty_score: nil).average(:difficulty_score)&.round(2)
        },
        breakdown: {
          by_category: work_logs.group(:category).count,
          by_project: work_logs.group(:project_name).count,
          by_status: work_logs.group(:status).count
        },
        trends: generate_daily_trends(work_logs, start_date, end_date)
      }

      render json: {
        success: true,
        data: stats_data,
        message: '作業ログ統計を取得しました'
      }, status: :ok
    rescue StandardError => e
      Rails.logger.error "Work log stats error: #{e.message}"
      render json: {
        success: false,
        error: '統計データの取得に失敗しました',
        details: e.message
      }, status: :internal_server_error
    end
  end

  # 生産性分析を取得
  # @route GET /api/v1/work_logs/productivity
  # @param [Integer] days 分析期間（日数）
  # @response [JSON] 生産性分析
  def productivity
    begin
      days = params[:days]&.to_i || 30
      days = [days, 365].min

      work_logs = current_user.work_logs.where('started_at >= ?', days.days.ago)

      productivity_data = {
        productivity_trends: calculate_productivity_trends(work_logs, days),
        time_distribution: calculate_time_distribution(work_logs),
        efficiency_metrics: calculate_efficiency_metrics(work_logs),
        recommendations: generate_productivity_recommendations(work_logs)
      }

      render json: {
        success: true,
        data: productivity_data,
        period_days: days,
        message: "#{days}日間の生産性分析を完了しました"
      }, status: :ok
    rescue StandardError => e
      Rails.logger.error "Work log productivity error: #{e.message}"
      render json: {
        success: false,
        error: '生産性分析に失敗しました',
        details: e.message
      }, status: :internal_server_error
    end
  end

  private

  # 作業ログを設定
  def set_work_log
    @work_log = current_user.work_logs.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: {
      success: false,
      error: '作業ログが見つかりません'
    }, status: :not_found
  end

  # 作業ログパラメーターを許可
  def work_log_params
    params.require(:work_log).permit(
      :title, :description, :category, :project_name, :started_at, :ended_at,
      :mood_score, :productivity_score, :difficulty_score, :notes, :location,
      :is_billable, :status,
      tags: []
    )
  end

  # 作業ログサマリーを整形
  # @param [WorkLog] work_log 作業ログ
  # @return [Hash] 整形されたサマリーデータ
  def format_work_log_summary(work_log)
    {
      id: work_log.id,
      title: work_log.title,
      description: work_log.description&.truncate(100),
      category: work_log.category,
      project_name: work_log.project_name,
      started_at: work_log.started_at,
      ended_at: work_log.ended_at,
      duration_minutes: work_log.duration_minutes,
      status: work_log.status,
      mood_score: work_log.mood_score,
      productivity_score: work_log.productivity_score,
      difficulty_score: work_log.difficulty_score,
      is_billable: work_log.is_billable,
      tags: work_log.tags,
      kpt_sessions_count: work_log.work_log_kpt_links.count,
      created_at: work_log.created_at,
      updated_at: work_log.updated_at
    }
  end

  # 作業ログ詳細を整形
  # @param [WorkLog] work_log 作業ログ
  # @return [Hash] 整形された詳細データ
  def format_work_log_detail(work_log)
    {
      id: work_log.id,
      title: work_log.title,
      description: work_log.description,
      category: work_log.category,
      project_name: work_log.project_name,
      started_at: work_log.started_at,
      ended_at: work_log.ended_at,
      duration_minutes: work_log.duration_minutes,
      duration_formatted: format_duration(work_log.duration_minutes),
      status: work_log.status,
      mood_score: work_log.mood_score,
      productivity_score: work_log.productivity_score,
      difficulty_score: work_log.difficulty_score,
      tags: work_log.tags,
      notes: work_log.notes,
      location: work_log.location,
      is_billable: work_log.is_billable,
      linked_kpt_sessions: work_log.work_log_kpt_links.includes(:kpt_session).map { |link| format_kpt_link(link) },
      created_at: work_log.created_at,
      updated_at: work_log.updated_at
    }
  end

  # KPT連携情報を整形
  # @param [WorkLogKptLink] link 連携情報
  # @return [Hash] 整形された連携データ
  def format_kpt_link(link)
    {
      id: link.id,
      kpt_session: {
        id: link.kpt_session.id,
        title: link.kpt_session.title,
        session_date: link.kpt_session.session_date,
        status: link.kpt_session.status
      },
      relevance_score: link.relevance_score,
      notes: link.notes,
      created_at: link.created_at
    }
  end

  # 期間サマリーを計算
  # @param [ActiveRecord::Relation] work_logs 作業ログクエリ
  # @return [Hash] 期間サマリー
  def calculate_period_summary(work_logs)
    total_duration = work_logs.sum(:duration_minutes) || 0
    billable_duration = work_logs.where(is_billable: true).sum(:duration_minutes) || 0

    {
      total_logs: work_logs.count,
      total_duration_minutes: total_duration,
      total_duration_formatted: format_duration(total_duration),
      billable_duration_minutes: billable_duration,
      billable_duration_formatted: format_duration(billable_duration),
      average_session_duration: work_logs.count > 0 ? (total_duration / work_logs.count).round : 0
    }
  end

  # 日別トレンドを生成
  # @param [ActiveRecord::Relation] work_logs 作業ログクエリ
  # @param [Date] start_date 開始日
  # @param [Date] end_date 終了日
  # @return [Array] 日別トレンドデータ
  def generate_daily_trends(work_logs, start_date, end_date)
    (start_date..end_date).map do |date|
      day_logs = work_logs.where(started_at: date.beginning_of_day..date.end_of_day)
      
      {
        date: date,
        logs_count: day_logs.count,
        total_duration: day_logs.sum(:duration_minutes) || 0,
        avg_mood: day_logs.where.not(mood_score: nil).average(:mood_score)&.round(2),
        avg_productivity: day_logs.where.not(productivity_score: nil).average(:productivity_score)&.round(2)
      }
    end
  end

  # 時間の整形
  # @param [Integer, nil] minutes 分数
  # @return [String] 整形された時間文字列
  def format_duration(minutes)
    return '0分' if minutes.nil? || minutes.zero?

    hours = minutes / 60
    mins = minutes % 60

    if hours > 0
      "#{hours}時間#{mins}分"
    else
      "#{mins}分"
    end
  end

  # 生産性トレンドを計算
  def calculate_productivity_trends(work_logs, days)
    # 週別の生産性推移
    weeks = (days / 7.0).ceil
    (0...weeks).map do |i|
      week_start = (i * 7).days.ago.beginning_of_day
      week_end = ((i * 7) - 6).days.ago.end_of_day
      week_logs = work_logs.where(started_at: week_end..week_start)
      
      {
        week: "#{week_end.strftime('%m/%d')}-#{week_start.strftime('%m/%d')}",
        total_duration: week_logs.sum(:duration_minutes) || 0,
        avg_productivity: week_logs.where.not(productivity_score: nil).average(:productivity_score)&.round(2),
        logs_count: week_logs.count
      }
    end.reverse
  end

  # 時間分布を計算
  def calculate_time_distribution(work_logs)
    {
      by_hour: work_logs.group_by_hour(:started_at).count,
      by_day_of_week: work_logs.group_by_day_of_week(:started_at).count,
      by_category: work_logs.group(:category).sum(:duration_minutes)
    }
  end

  # 効率性メトリクスを計算
  def calculate_efficiency_metrics(work_logs)
    completed_logs = work_logs.where(status: 'completed')
    
    {
      completion_rate: work_logs.count > 0 ? (completed_logs.count.to_f / work_logs.count * 100).round(2) : 0,
      average_session_length: completed_logs.count > 0 ? (completed_logs.sum(:duration_minutes) / completed_logs.count).round : 0,
      productive_hours_per_day: work_logs.where.not(productivity_score: nil).where('productivity_score >= 4').sum(:duration_minutes) / 60.0 / 30
    }
  end

  # 生産性向上の推奨事項を生成
  def generate_productivity_recommendations(work_logs)
    recommendations = []
    
    avg_productivity = work_logs.where.not(productivity_score: nil).average(:productivity_score)
    if avg_productivity && avg_productivity < 3.0
      recommendations << '生産性スコアが低めです。作業環境や集中方法を見直してみてください'
    end
    
    long_sessions = work_logs.where('duration_minutes > 240').count
    if long_sessions > work_logs.count * 0.3
      recommendations << '長時間の作業セッションが多いです。適度な休憩を取ることをお勧めします'
    end
    
    recommendations << '定期的な作業ログの記録を継続してください'
    recommendations
  end
end 