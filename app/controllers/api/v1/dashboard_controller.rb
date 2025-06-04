# frozen_string_literal: true

# ダッシュボードAPIコントローラー
#
# @description ダッシュボード用のAPI機能を提供
# ユーザーのKPTアクティビティ統計、最近のアクティビティ、
# 概要データなどを取得する機能を実装
#
# @endpoints
# - GET /api/v1/dashboard ダッシュボード基本情報
# - GET /api/v1/dashboard/summary ダッシュボードサマリー
# - GET /api/v1/dashboard/stats 統計データ
# - GET /api/v1/dashboard/activity 最近のアクティビティ
# - GET /api/v1/dashboard/overview KPT概要統計
class Api::V1::DashboardController < ApplicationController
  before_action :authenticate_user!

  # ダッシュボード基本情報を取得
  # @route GET /api/v1/dashboard
  # @response [JSON] ダッシュボード基本情報
  def index
    begin
      dashboard_data = {
        user: {
          display_name: current_user.display_name,
          avatar_url: current_user.avatar_url,
          member_since: current_user.created_at.strftime('%Y年%m月'),
          timezone: current_user.timezone,
          pro_plan: current_user.pro_plan?
        },
        quick_stats: {
          total_sessions: current_user.kpt_sessions.count,
          active_sessions: current_user.kpt_sessions.active.count,
          completed_sessions: current_user.kpt_sessions.completed.count,
          total_items: current_user.kpt_items.count,
          active_items: current_user.kpt_items.active.count,
          overdue_items: current_user.kpt_items.overdue.count
        },
        recent_activities: current_user.recent_kpt_activity(5).map { |activity| format_activity(activity) },
        navigation: {
          sessions_url: '/api/v1/kpt_sessions',
          items_url: '/api/v1/kpt_items',
          stats_url: '/api/v1/dashboard/stats',
          summary_url: '/api/v1/dashboard/summary'
        }
      }

      render json: {
        success: true,
        data: dashboard_data,
        message: 'ダッシュボード情報を取得しました'
      }, status: :ok
    rescue StandardError => e
      render_error(error: 'ダッシュボード情報の取得中にエラーが発生しました', status: :internal_server_error)
    end
  end

  # ダッシュボードサマリーを取得
  # @route GET /api/v1/dashboard/summary
  # @response [JSON] ダッシュボードサマリーデータ
  def summary
    begin
      summary_data = current_user.dashboard_summary

      render json: {
        success: true,
        data: summary_data,
        message: 'ダッシュボードサマリーを取得しました'
      }, status: :ok
    rescue StandardError => e
      render_error(error: 'サマリーデータの取得中にエラーが発生しました', status: :internal_server_error)
    end
  end

  # 統計データを取得
  # @route GET /api/v1/dashboard/stats
  # @param [String] period 期間 (week, month, quarter, year)
  # @response [JSON] 統計データ
  def stats
    begin
      period = params[:period] || 'month'
      
      stats_data = case period
                   when 'week'
                     get_weekly_stats
                   when 'month'
                     get_monthly_stats
                   when 'quarter'
                     get_quarterly_stats
                   when 'year'
                     get_yearly_stats
                   else
                     get_monthly_stats
                   end

      render json: {
        success: true,
        data: stats_data,
        period: period,
        message: "#{period}の統計データを取得しました"
      }, status: :ok
    rescue StandardError => e
      render_error(error: '統計データの取得中にエラーが発生しました', status: :internal_server_error)
    end
  end

  # 最近のアクティビティを取得
  # @route GET /api/v1/dashboard/activity
  # @param [Integer] limit 取得件数 (デフォルト: 20)
  # @response [JSON] 最近のアクティビティ
  def activity
    begin
      limit = [params[:limit].to_i, 50].min
      limit = 20 if limit <= 0

      activities = current_user.recent_kpt_activity(limit)
      
      # アクティビティデータを整形
      formatted_activities = activities.map do |activity|
        format_activity(activity)
      end

      render json: {
        success: true,
        data: {
          activities: formatted_activities,
          total_count: formatted_activities.size
        },
        message: '最近のアクティビティを取得しました'
      }, status: :ok
    rescue StandardError => e
      render_error(error: 'アクティビティデータの取得中にエラーが発生しました', status: :internal_server_error)
    end
  end

  # KPT概要統計を取得
  # @route GET /api/v1/dashboard/overview
  # @response [JSON] KPT概要統計
  def overview
    begin
      overview_data = current_user.kpt_overview_stats
      
      # 追加のメトリクスを計算
      additional_metrics = calculate_additional_metrics

      render json: {
        success: true,
        data: {
          **overview_data,
          metrics: additional_metrics
        },
        message: 'KPT概要統計を取得しました'
      }, status: :ok
    rescue StandardError => e
      render_error(error: '概要統計の取得中にエラーが発生しました', status: :internal_server_error)
    end
  end

  # KPTアイテムの傾向分析を取得
  # @route GET /api/v1/dashboard/trends
  # @param [Integer] days 分析期間（日数、デフォルト: 30）
  # @response [JSON] 傾向分析データ
  def trends
    begin
      days = params[:days]&.to_i || 30
      days = [days, 365].min # 最大1年
      days = 7 if days < 7    # 最小1週間

      trends_data = {
        emotion_trend: KptItem.emotion_trend(current_user, days),
        impact_distribution: KptItem.impact_distribution(current_user),
        type_stats: KptItem.type_stats(current_user, days.days.ago, Date.current),
        monthly_trends: KptSession.monthly_stats(current_user, 6)
      }

      render json: {
        success: true,
        data: trends_data,
        period_days: days,
        message: "#{days}日間の傾向分析を取得しました"
      }, status: :ok
    rescue StandardError => e
      render_error(error: '傾向分析の取得中にエラーが発生しました', status: :internal_server_error)
    end
  end

  private

  # 週次統計を取得
  # @return [Hash] 週次統計データ
  def get_weekly_stats
    start_date = 1.week.ago.beginning_of_week
    end_date = Date.current.end_of_week
    
    sessions = current_user.kpt_sessions.by_date_range(start_date, end_date)
    items = current_user.kpt_items.joins(:kpt_session)
                        .where(kpt_sessions: { session_date: start_date..end_date })

    {
      period_start: start_date,
      period_end: end_date,
      sessions: {
        total: sessions.count,
        completed: sessions.completed.count,
        completion_rate: calculate_completion_rate(sessions)
      },
      items: get_items_stats(items),
      daily_breakdown: get_daily_breakdown(start_date, end_date)
    }
  end

  # 月次統計を取得
  # @return [Hash] 月次統計データ
  def get_monthly_stats
    current_user.monthly_kpt_stats.merge({
      period_start: Date.current.beginning_of_month,
      period_end: Date.current.end_of_month,
      comparison: get_period_comparison('month')
    })
  end

  # 四半期統計を取得
  # @return [Hash] 四半期統計データ
  def get_quarterly_stats
    start_date = Date.current.beginning_of_quarter
    end_date = Date.current.end_of_quarter
    
    sessions = current_user.kpt_sessions.by_date_range(start_date, end_date)
    items = current_user.kpt_items.joins(:kpt_session)
                        .where(kpt_sessions: { session_date: start_date..end_date })

    {
      period_start: start_date,
      period_end: end_date,
      sessions: {
        total: sessions.count,
        completed: sessions.completed.count,
        completion_rate: calculate_completion_rate(sessions)
      },
      items: get_items_stats(items),
      monthly_breakdown: get_monthly_breakdown(start_date, end_date)
    }
  end

  # 年次統計を取得
  # @return [Hash] 年次統計データ
  def get_yearly_stats
    start_date = Date.current.beginning_of_year
    end_date = Date.current.end_of_year
    
    sessions = current_user.kpt_sessions.by_date_range(start_date, end_date)
    items = current_user.kpt_items.joins(:kpt_session)
                        .where(kpt_sessions: { session_date: start_date..end_date })

    {
      period_start: start_date,
      period_end: end_date,
      sessions: {
        total: sessions.count,
        completed: sessions.completed.count,
        completion_rate: calculate_completion_rate(sessions)
      },
      items: get_items_stats(items),
      quarterly_breakdown: get_quarterly_breakdown(start_date, end_date)
    }
  end

  # アイテム統計を取得
  # @param [ActiveRecord::Relation] items アイテムのクエリ
  # @return [Hash] アイテム統計
  def get_items_stats(items)
    {
      total: items.count,
      completed: items.completed.count,
      active: items.active.count,
      keep: items.keeps.count,
      problem: items.problems.count,
      try: items.tries.count,
      average_emotion_score: items.with_emotion_score.average(:emotion_score)&.round(2),
      average_impact_score: items.with_impact_score.average(:impact_score)&.round(2)
    }
  end

  # 期間比較データを取得
  # @param [String] period 期間タイプ
  # @return [Hash] 比較データ
  def get_period_comparison(period)
    case period
    when 'month'
      current_stats = current_user.monthly_kpt_stats
      previous_month = 1.month.ago
      previous_sessions = current_user.kpt_sessions
                                     .by_date_range(previous_month.beginning_of_month, previous_month.end_of_month)
      
      {
        sessions_change: calculate_change(current_stats[:sessions_count], previous_sessions.count),
        completion_change: calculate_change(current_stats[:completed_sessions], previous_sessions.completed.count)
      }
    else
      {}
    end
  end

  # 日別内訳を取得
  # @param [Date] start_date 開始日
  # @param [Date] end_date 終了日
  # @return [Array] 日別データ
  def get_daily_breakdown(start_date, end_date)
    (start_date..end_date).map do |date|
      sessions = current_user.kpt_sessions.where(session_date: date)
      items = current_user.kpt_items.joins(:kpt_session)
                          .where(kpt_sessions: { session_date: date })

      {
        date: date,
        sessions_count: sessions.count,
        items_count: items.count,
        completed_items: items.completed.count
      }
    end
  end

  # 月別内訳を取得
  # @param [Date] start_date 開始日
  # @param [Date] end_date 終了日
  # @return [Array] 月別データ
  def get_monthly_breakdown(start_date, end_date)
    current_month = start_date.beginning_of_month
    end_month = end_date.end_of_month
    
    breakdown = []
    while current_month <= end_month
      month_sessions = current_user.kpt_sessions
                                  .by_date_range(current_month, current_month.end_of_month)
      
      breakdown << {
        month: current_month.strftime('%Y-%m'),
        sessions_count: month_sessions.count,
        completed_sessions: month_sessions.completed.count
      }
      
      current_month = current_month.next_month.beginning_of_month
    end
    
    breakdown
  end

  # 四半期別内訳を取得
  # @param [Date] start_date 開始日
  # @param [Date] end_date 終了日
  # @return [Array] 四半期別データ
  def get_quarterly_breakdown(start_date, end_date)
    quarters = []
    current_quarter = start_date.beginning_of_quarter
    
    while current_quarter <= end_date
      quarter_sessions = current_user.kpt_sessions
                                    .by_date_range(current_quarter, current_quarter.end_of_quarter)
      
      quarters << {
        quarter: "#{current_quarter.year}Q#{(current_quarter.month - 1) / 3 + 1}",
        sessions_count: quarter_sessions.count,
        completed_sessions: quarter_sessions.completed.count
      }
      
      current_quarter = (current_quarter + 3.months).beginning_of_quarter
    end
    
    quarters
  end

  # 完了率を計算
  # @param [ActiveRecord::Relation] sessions セッションのクエリ
  # @return [Float] 完了率
  def calculate_completion_rate(sessions)
    total = sessions.count
    return 0.0 if total.zero?
    
    completed = sessions.completed.count
    (completed.to_f / total * 100).round(2)
  end

  # 変化率を計算
  # @param [Integer] current 現在の値
  # @param [Integer] previous 前の値
  # @return [Float] 変化率
  def calculate_change(current, previous)
    return 0.0 if previous.zero?
    
    ((current - previous).to_f / previous * 100).round(2)
  end

  # アクティビティデータを整形
  # @param [Hash] activity アクティビティデータ
  # @return [Hash] 整形されたアクティビティデータ
  def format_activity(activity)
    object = activity[:object]
    
    case activity[:type]
    when 'session'
      {
        id: object.id,
        type: activity[:type],
        action: activity[:action],
        title: object.title,
        session_date: object.session_date,
        status: object.status,
        items_count: object.kpt_items_count[:total],
        timestamp: activity[:timestamp]
      }
    when 'item'
      {
        id: object.id,
        type: activity[:type],
        action: activity[:action],
        content: object.content.truncate(100),
        item_type: object.type,
        priority: object.priority,
        session_title: object.kpt_session.title,
        timestamp: activity[:timestamp]
      }
    end
  end

  # 追加メトリクスを計算
  # @return [Hash] 追加メトリクス
  def calculate_additional_metrics
    {
      productivity_score: calculate_productivity_score,
      engagement_level: calculate_engagement_level,
      improvement_trend: calculate_improvement_trend
    }
  end

  # 生産性スコアを計算
  # @return [Float] 生産性スコア (0-100)
  def calculate_productivity_score
    sessions = current_user.kpt_sessions.where('created_at >= ?', 30.days.ago)
    return 0.0 if sessions.count.zero?

    completion_rate = sessions.completed.count.to_f / sessions.count
    avg_items_per_session = current_user.kpt_items.joins(:kpt_session)
                                        .where(kpt_sessions: { id: sessions.ids })
                                        .count.to_f / sessions.count

    score = (completion_rate * 60 + [avg_items_per_session * 8, 40].min)
    [score, 100].min.round(2)
  end

  # エンゲージメントレベルを計算
  # @return [String] エンゲージメントレベル
  def calculate_engagement_level
    recent_sessions = current_user.kpt_sessions.where('created_at >= ?', 14.days.ago).count
    
    case recent_sessions
    when 0..1
      'low'
    when 2..5
      'medium'
    else
      'high'
    end
  end

  # 改善トレンドを計算
  # @return [String] 改善トレンド
  def calculate_improvement_trend
    recent_completion_rate = current_user.kpt_items
                                        .where('completed_at >= ?', 14.days.ago)
                                        .completed.count.to_f
    previous_completion_rate = current_user.kpt_items
                                          .where(completed_at: 28.days.ago..14.days.ago)
                                          .completed.count.to_f

    if recent_completion_rate > previous_completion_rate * 1.2
      'improving'
    elsif recent_completion_rate < previous_completion_rate * 0.8
      'declining'
    else
      'stable'
    end
  end

  def render_error(error:, status:)
    render json: {
      success: false,
      error: error
    }, status: status
  end
end 