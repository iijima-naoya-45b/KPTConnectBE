# frozen_string_literal: true

# 個人振り返りカレンダーAPIコントローラー
#
# @description 個人の振り返りカレンダー機能を提供するAPIコントローラー
# KPTセッション、作業ログ、成長データを統合してカレンダー形式で表示
#
# @example API使用例
# GET /api/v1/calendar/reflection_calendar?year=2025&month=6
# GET /api/v1/calendar/monthly_data?year=2025&month=6
# GET /api/v1/calendar/growth_timeline?start_date=2025-01-01&end_date=2025-12-31
class Api::V1::Calendar::ReflectionsController < ApplicationController
  before_action :require_login
  before_action :set_date_params, only: [:index, :monthly_data]
  before_action :set_date_range_params, only: [:growth_timeline, :growth_analytics]

  # カレンダー表示用データを取得
  # @route GET /api/v1/calendar/reflection_calendar
  # @param [Integer] year 年
  # @param [Integer] month 月
  # @return [JSON] カレンダー表示用データ
  def index
    begin
      calendar_data = generate_calendar_data(@year, @month)
      
      render json: {
        success: true,
        data: {
          year: @year,
          month: @month,
          calendar_data: calendar_data,
          monthly_summary: monthly_summary(@year, @month)
        },
        message: 'カレンダーデータを取得しました'
      }
    rescue StandardError => e
      render json: {
        success: false,
        error: 'カレンダーデータの取得に失敗しました',
        details: e.message
      }, status: :internal_server_error
    end
  end

  # 月次データを取得
  # @route GET /api/v1/calendar/monthly_data
  # @param [Integer] year 年
  # @param [Integer] month 月
  # @return [JSON] 月次統計データ
  def monthly_data
    begin
      start_date = Date.new(@year, @month, 1)
      end_date = start_date.end_of_month

      sessions = current_user.kpt_sessions.by_date_range(start_date, end_date)
      work_logs = current_user.work_logs.where(date: start_date..end_date) if current_user.respond_to?(:work_logs)

      data = {
        kpt_sessions: {
          total: sessions.count,
          completed: sessions.completed.count,
          by_type: sessions.group(:status).count,
          items_count: sessions.joins(:kpt_items).group('kpt_items.type').count
        },
        productivity: calculate_monthly_productivity(start_date, end_date),
        growth_metrics: calculate_growth_metrics(start_date, end_date),
        reflection_streak: calculate_reflection_streak(end_date)
      }

      render json: {
        success: true,
        data: data,
        message: '月次データを取得しました'
      }
    rescue StandardError => e
      render json: {
        success: false,
        error: '月次データの取得に失敗しました',
        details: e.message
      }, status: :internal_server_error
    end
  end

  # 成長タイムラインを取得
  # @route GET /api/v1/calendar/growth_timeline
  # @param [Date] start_date 開始日
  # @param [Date] end_date 終了日
  # @return [JSON] 成長タイムラインデータ
  def growth_timeline
    begin
      timeline_data = []
      
      # KPTセッションデータ
      sessions = current_user.kpt_sessions.by_date_range(@start_date, @end_date).recent
      sessions.each do |session|
        timeline_data << {
          date: session.session_date,
          type: 'kpt_session',
          title: session.title,
          description: session.description,
          status: session.status,
          items_count: session.kpt_items.count,
          progress_rate: session.progress_rate,
          emotion_score: session.average_emotion_score,
          impact_score: session.average_impact_score,
          url: "/dashboard/kpt/#{session.id}"
        }
      end

      # 作業ログデータ（存在する場合）
      if current_user.respond_to?(:work_logs)
        work_logs = current_user.work_logs.where(date: @start_date..@end_date).order(date: :desc)
        work_logs.each do |log|
          timeline_data << {
            date: log.date,
            type: 'work_log',
            title: log.title || "作業ログ",
            description: log.description,
            duration: log.duration,
            productivity_score: log.productivity_score,
            url: "/dashboard/work-logs/#{log.id}"
          }
        end
      end

      # 日付順にソート
      timeline_data.sort_by! { |item| item[:date] }.reverse!

      render json: {
        success: true,
        data: {
          timeline: timeline_data,
          period: {
            start_date: @start_date,
            end_date: @end_date,
            total_days: (@end_date - @start_date).to_i + 1
          },
          summary: calculate_timeline_summary(timeline_data)
        },
        message: '成長タイムラインを取得しました'
      }
    rescue StandardError => e
      render json: {
        success: false,
        error: '成長タイムラインの取得に失敗しました',
        details: e.message
      }, status: :internal_server_error
    end
  end

  # 成長分析データを取得
  # @route GET /api/v1/calendar/growth_analytics
  # @param [Date] start_date 開始日
  # @param [Date] end_date 終了日
  # @return [JSON] 成長分析データ
  def growth_analytics
    begin
      analytics_data = {
        reflection_frequency: calculate_reflection_frequency(@start_date, @end_date),
        emotion_trends: calculate_emotion_trends(@start_date, @end_date),
        impact_trends: calculate_impact_trends(@start_date, @end_date),
        kpt_patterns: analyze_kpt_patterns(@start_date, @end_date),
        growth_indicators: calculate_growth_indicators(@start_date, @end_date),
        recommendations: generate_recommendations(@start_date, @end_date)
      }

      render json: {
        success: true,
        data: analytics_data,
        message: '成長分析データを取得しました'
      }
    rescue StandardError => e
      render json: {
        success: false,
        error: '成長分析データの取得に失敗しました',
        details: e.message
      }, status: :internal_server_error
    end
  end

  # 個人統計を取得
  # @route GET /api/v1/calendar/personal_stats
  # @return [JSON] 個人統計データ
  def personal_stats
    begin
      stats = {
        total_sessions: current_user.kpt_sessions.count,
        total_items: current_user.kpt_sessions.joins(:kpt_items).count,
        completion_rate: calculate_overall_completion_rate,
        current_streak: calculate_current_streak,
        longest_streak: calculate_longest_streak,
        monthly_average: calculate_monthly_average,
        most_productive_day: find_most_productive_day,
        popular_tags: KptSession.popular_tags(current_user),
        recent_achievements: get_recent_achievements
      }

      render json: {
        success: true,
        data: stats,
        message: '個人統計を取得しました'
      }
    rescue StandardError => e
      render json: {
        success: false,
        error: '個人統計の取得に失敗しました',
        details: e.message
      }, status: :internal_server_error
    end
  end

  # 振り返り日をマーク
  # @route POST /api/v1/calendar/mark_reflection
  # @param [Date] date 日付
  # @param [String] note メモ（オプション）
  # @return [JSON] 処理結果
  def mark_reflection
    begin
      date = Date.parse(params[:date])
      note = params[:note]

      # 振り返り記録を作成または更新
      reflection = current_user.reflection_marks.find_or_initialize_by(date: date)
      reflection.note = note if note.present?
      reflection.save!

      render json: {
        success: true,
        data: {
          date: date,
          note: reflection.note,
          created_at: reflection.created_at
        },
        message: '振り返り日をマークしました'
      }
    rescue Date::Error
      render json: {
        success: false,
        error: '無効な日付形式です'
      }, status: :bad_request
    rescue StandardError => e
      render json: {
        success: false,
        error: '振り返り日のマークに失敗しました',
        details: e.message
      }, status: :internal_server_error
    end
  end

  # 振り返り日のマークを解除
  # @route DELETE /api/v1/calendar/unmark_reflection
  # @param [Date] date 日付
  # @return [JSON] 処理結果
  def unmark_reflection
    begin
      date = Date.parse(params[:date])
      
      reflection = current_user.reflection_marks.find_by(date: date)
      if reflection
        reflection.destroy!
        message = '振り返り日のマークを解除しました'
      else
        message = '指定された日付にマークがありませんでした'
      end

      render json: {
        success: true,
        data: { date: date },
        message: message
      }
    rescue Date::Error
      render json: {
        success: false,
        error: '無効な日付形式です'
      }, status: :bad_request
    rescue StandardError => e
      render json: {
        success: false,
        error: '振り返り日マークの解除に失敗しました',
        details: e.message
      }, status: :internal_server_error
    end
  end

  private

  # 日付パラメータを設定
  def set_date_params
    @year = params[:year]&.to_i || Date.current.year
    @month = params[:month]&.to_i || Date.current.month

    # バリデーション
    unless (1900..2100).include?(@year) && (1..12).include?(@month)
      render json: {
        success: false,
        error: '無効な年月が指定されました'
      }, status: :bad_request
      return
    end
  end

  # 日付範囲パラメータを設定
  def set_date_range_params
    @start_date = params[:start_date]&.to_date || 6.months.ago.to_date
    @end_date = params[:end_date]&.to_date || Date.current

    if @start_date > @end_date
      render json: {
        success: false,
        error: '開始日が終了日より後になっています'
      }, status: :bad_request
      return
    end
  rescue Date::Error
    render json: {
      success: false,
      error: '無効な日付形式です'
    }, status: :bad_request
  end

  # カレンダーデータを生成
  # @param [Integer] year 年
  # @param [Integer] month 月
  # @return [Array] カレンダーデータ
  def generate_calendar_data(year, month)
    start_date = Date.new(year, month, 1)
    end_date = start_date.end_of_month
    
    # 月のすべての日付を生成
    calendar_data = []
    (start_date..end_date).each do |date|
      day_data = {
        date: date,
        day: date.day,
        weekday: date.wday,
        has_kpt_session: false,
        kpt_sessions: [],
        reflection_score: 0,
        productivity_level: 'none'
      }

      # KPTセッションデータを取得
      sessions = current_user.kpt_sessions.where(session_date: date)
      if sessions.any?
        day_data[:has_kpt_session] = true
        day_data[:kpt_sessions] = sessions.map do |session|
          {
            id: session.id,
            title: session.title,
            status: session.status,
            items_count: session.kpt_items.count,
            progress_rate: session.progress_rate
          }
        end
        day_data[:reflection_score] = calculate_daily_reflection_score(sessions)
      end

      # 生産性レベルを計算
      day_data[:productivity_level] = calculate_productivity_level(date)

      calendar_data << day_data
    end

    calendar_data
  end

  # 月次サマリーを計算
  # @param [Integer] year 年
  # @param [Integer] month 月
  # @return [Hash] 月次サマリー
  def monthly_summary(year, month)
    start_date = Date.new(year, month, 1)
    end_date = start_date.end_of_month
    
    sessions = current_user.kpt_sessions.by_date_range(start_date, end_date)
    
    {
      total_reflection_days: sessions.distinct.count(:session_date),
      total_sessions: sessions.count,
      completed_sessions: sessions.completed.count,
      total_items: sessions.joins(:kpt_items).count,
      average_items_per_session: sessions.count > 0 ? (sessions.joins(:kpt_items).count.to_f / sessions.count).round(1) : 0,
      reflection_streak: calculate_monthly_streak(start_date, end_date)
    }
  end

  # 日次振り返りスコアを計算
  # @param [Array<KptSession>] sessions セッション配列
  # @return [Integer] 振り返りスコア (0-100)
  def calculate_daily_reflection_score(sessions)
    return 0 if sessions.empty?

    total_score = sessions.sum do |session|
      base_score = 20 # 基本スコア
      base_score += session.kpt_items.count * 5 # アイテム数に応じて加点
      base_score += session.progress_rate * 30 # 進捗率に応じて加点
      base_score += (session.average_emotion_score || 0) * 10 # 感情スコアに応じて加点
      [base_score, 100].min # 最大100点
    end

    (total_score / sessions.count).round
  end

  # 生産性レベルを計算
  # @param [Date] date 日付
  # @return [String] 生産性レベル
  def calculate_productivity_level(date)
    # 作業ログがある場合の処理
    if current_user.respond_to?(:work_logs)
      work_log = current_user.work_logs.find_by(date: date)
      return 'none' unless work_log
      
      if work_log.productivity_score
        case work_log.productivity_score
        when 0..30 then 'low'
        when 31..70 then 'medium'
        when 71..100 then 'high'
        else 'none'
        end
      else
        work_log.duration && work_log.duration > 4 ? 'medium' : 'low'
      end
    else
      # KPTセッションベースの簡易計算
      sessions = current_user.kpt_sessions.where(session_date: date)
      return 'none' if sessions.empty?
      
      total_items = sessions.sum { |s| s.kpt_items.count }
      case total_items
      when 0..2 then 'low'
      when 3..8 then 'medium'
      else 'high'
      end
    end
  end

  # 月次生産性を計算
  # @param [Date] start_date 開始日
  # @param [Date] end_date 終了日
  # @return [Hash] 生産性データ
  def calculate_monthly_productivity(start_date, end_date)
    sessions = current_user.kpt_sessions.by_date_range(start_date, end_date)
    
    {
      active_days: sessions.distinct.count(:session_date),
      total_days: (end_date - start_date).to_i + 1,
      activity_rate: sessions.distinct.count(:session_date).to_f / ((end_date - start_date).to_i + 1) * 100,
      average_daily_items: sessions.count > 0 ? (sessions.joins(:kpt_items).count.to_f / sessions.distinct.count(:session_date)).round(1) : 0
    }
  end

  # 成長指標を計算
  # @param [Date] start_date 開始日
  # @param [Date] end_date 終了日
  # @return [Hash] 成長指標
  def calculate_growth_metrics(start_date, end_date)
    sessions = current_user.kpt_sessions.by_date_range(start_date, end_date)
    
    {
      reflection_consistency: calculate_reflection_consistency(start_date, end_date),
      improvement_rate: calculate_improvement_rate(sessions),
      goal_achievement: calculate_goal_achievement_rate(sessions),
      learning_velocity: calculate_learning_velocity(sessions)
    }
  end

  # その他のヘルパーメソッド群
  def calculate_reflection_streak(end_date)
    # 振り返り連続日数を計算
    streak = 0
    current_date = end_date
    
    while current_date >= 30.days.ago
      if current_user.kpt_sessions.where(session_date: current_date).exists?
        streak += 1
        current_date -= 1.day
      else
        break
      end
    end
    
    streak
  end

  def calculate_reflection_frequency(start_date, end_date)
    total_days = (end_date - start_date).to_i + 1
    reflection_days = current_user.kpt_sessions.by_date_range(start_date, end_date).distinct.count(:session_date)
    
    {
      total_days: total_days,
      reflection_days: reflection_days,
      frequency_rate: (reflection_days.to_f / total_days * 100).round(1)
    }
  end

  def calculate_emotion_trends(start_date, end_date)
    # 感情スコアの推移を週単位で集計
    weekly_data = []
    current_week_start = start_date.beginning_of_week
    
    while current_week_start <= end_date
      week_end = [current_week_start.end_of_week, end_date].min
      week_sessions = current_user.kpt_sessions.by_date_range(current_week_start, week_end)
      
      emotion_scores = week_sessions.joins(:kpt_items)
                                   .where.not(kpt_items: { emotion_score: nil })
                                   .pluck('kpt_items.emotion_score')
      
      avg_emotion = emotion_scores.any? ? (emotion_scores.sum.to_f / emotion_scores.size).round(1) : nil
      
      weekly_data << {
        week_start: current_week_start,
        week_end: week_end,
        average_emotion_score: avg_emotion,
        sessions_count: week_sessions.count
      }
      
      current_week_start += 1.week
    end
    
    weekly_data
  end

  def calculate_impact_trends(start_date, end_date)
    # 影響度スコアの推移を週単位で集計
    weekly_data = []
    current_week_start = start_date.beginning_of_week
    
    while current_week_start <= end_date
      week_end = [current_week_start.end_of_week, end_date].min
      week_sessions = current_user.kpt_sessions.by_date_range(current_week_start, week_end)
      
      impact_scores = week_sessions.joins(:kpt_items)
                                  .where.not(kpt_items: { impact_score: nil })
                                  .pluck('kpt_items.impact_score')
      
      avg_impact = impact_scores.any? ? (impact_scores.sum.to_f / impact_scores.size).round(1) : nil
      
      weekly_data << {
        week_start: current_week_start,
        week_end: week_end,
        average_impact_score: avg_impact,
        sessions_count: week_sessions.count
      }
      
      current_week_start += 1.week
    end
    
    weekly_data
  end

  def analyze_kpt_patterns(start_date, end_date)
    sessions = current_user.kpt_sessions.by_date_range(start_date, end_date)
    
    {
      keep_patterns: analyze_item_patterns(sessions, 'keep'),
      problem_patterns: analyze_item_patterns(sessions, 'problem'),
      try_patterns: analyze_item_patterns(sessions, 'try')
    }
  end

  def analyze_item_patterns(sessions, item_type)
    items = KptItem.joins(:kpt_session)
                   .where(kpt_session: sessions, type: item_type)
    
    {
      total_count: items.count,
      average_per_session: sessions.count > 0 ? (items.count.to_f / sessions.count).round(1) : 0,
      priority_distribution: items.group(:priority).count,
      status_distribution: items.group(:status).count,
      completion_rate: items.count > 0 ? (items.where(status: 'completed').count.to_f / items.count * 100).round(1) : 0
    }
  end

  def calculate_growth_indicators(start_date, end_date)
    {
      reflection_consistency: calculate_reflection_consistency(start_date, end_date),
      goal_completion_trend: calculate_goal_completion_trend(start_date, end_date),
      learning_acceleration: calculate_learning_acceleration(start_date, end_date)
    }
  end

  def generate_recommendations(start_date, end_date)
    recommendations = []
    
    # 振り返り頻度に基づく推奨
    frequency = calculate_reflection_frequency(start_date, end_date)
    if frequency[:frequency_rate] < 50
      recommendations << {
        type: 'frequency',
        title: '振り返り頻度を上げましょう',
        description: '定期的な振り返りが成長の鍵です。週に3回以上の振り返りを目標にしてみてください。'
      }
    end
    
    # KPTバランスに基づく推奨
    sessions = current_user.kpt_sessions.by_date_range(start_date, end_date)
    if sessions.any?
      keep_count = sessions.joins(:kpt_items).where(kpt_items: { type: 'keep' }).count
      problem_count = sessions.joins(:kpt_items).where(kpt_items: { type: 'problem' }).count
      try_count = sessions.joins(:kpt_items).where(kpt_items: { type: 'try' }).count
      
      if problem_count > try_count * 2
        recommendations << {
          type: 'balance',
          title: 'Tryアイテムを増やしましょう',
          description: 'Problemに対する具体的な改善案（Try）を考えることで、より効果的な振り返りになります。'
        }
      end
    end
    
    recommendations
  end

  def calculate_timeline_summary(timeline_data)
    kpt_sessions = timeline_data.select { |item| item[:type] == 'kpt_session' }
    work_logs = timeline_data.select { |item| item[:type] == 'work_log' }
    
    {
      total_activities: timeline_data.count,
      kpt_sessions_count: kpt_sessions.count,
      work_logs_count: work_logs.count,
      average_progress: kpt_sessions.any? ? (kpt_sessions.sum { |s| s[:progress_rate] || 0 } / kpt_sessions.count).round(1) : 0
    }
  end

  # 簡略化されたメソッド群（実装を簡素化）
  def calculate_overall_completion_rate
    sessions = current_user.kpt_sessions
    return 0 if sessions.count.zero?
    
    completed_sessions = sessions.completed.count
    (completed_sessions.to_f / sessions.count * 100).round(1)
  end

  def calculate_current_streak
    calculate_reflection_streak(Date.current)
  end

  def calculate_longest_streak
    # 簡易実装：現在のストリークと同じとする
    calculate_current_streak
  end

  def calculate_monthly_average
    months_with_data = current_user.kpt_sessions.distinct.count('EXTRACT(YEAR FROM session_date) * 12 + EXTRACT(MONTH FROM session_date)')
    return 0 if months_with_data.zero?
    
    (current_user.kpt_sessions.count.to_f / months_with_data).round(1)
  end

  def find_most_productive_day
    day_counts = current_user.kpt_sessions.group('EXTRACT(DOW FROM session_date)').count
    return nil if day_counts.empty?
    
    most_productive_dow = day_counts.max_by { |_, count| count }.first
    Date::DAYNAMES[most_productive_dow.to_i]
  end

  def get_recent_achievements
    # 簡易実装：最近の完了セッション
    recent_completed = current_user.kpt_sessions.completed.recent.limit(3)
    recent_completed.map do |session|
      {
        type: 'session_completed',
        title: "KPTセッション完了: #{session.title}",
        date: session.completed_at&.to_date || session.session_date,
        description: "#{session.kpt_items.count}個のアイテムで振り返りを完了"
      }
    end
  end

  def calculate_reflection_consistency(start_date, end_date)
    # 簡易実装：週単位での一貫性
    total_weeks = ((end_date - start_date) / 7).ceil
    return 0 if total_weeks.zero?
    
    weeks_with_reflection = 0
    (0...total_weeks).each do |week_offset|
      week_start = start_date + (week_offset * 7).days
      week_end = [week_start + 6.days, end_date].min
      
      if current_user.kpt_sessions.by_date_range(week_start, week_end).exists?
        weeks_with_reflection += 1
      end
    end
    
    (weeks_with_reflection.to_f / total_weeks * 100).round(1)
  end

  def calculate_improvement_rate(sessions)
    # 簡易実装：完了率を改善率とする
    return 0 if sessions.count.zero?
    
    (sessions.completed.count.to_f / sessions.count * 100).round(1)
  end

  def calculate_goal_achievement_rate(sessions)
    # 簡易実装：Try itemsの完了率
    try_items = KptItem.joins(:kpt_session).where(kpt_session: sessions, type: 'try')
    return 0 if try_items.count.zero?
    
    completed_tries = try_items.where(status: 'completed').count
    (completed_tries.to_f / try_items.count * 100).round(1)
  end

  def calculate_learning_velocity(sessions)
    # 簡易実装：セッションあたりのアイテム数の増加率
    return 0 if sessions.count < 2
    
    recent_sessions = sessions.recent.limit(sessions.count / 2)
    older_sessions = sessions.recent.offset(sessions.count / 2)
    
    recent_avg = recent_sessions.joins(:kpt_items).count.to_f / recent_sessions.count
    older_avg = older_sessions.joins(:kpt_items).count.to_f / older_sessions.count
    
    return 0 if older_avg.zero?
    
    ((recent_avg - older_avg) / older_avg * 100).round(1)
  end

  def calculate_monthly_streak(start_date, end_date)
    streak = 0
    current_date = end_date
    
    while current_date >= start_date
      if current_user.kpt_sessions.where(session_date: current_date).exists?
        streak += 1
        current_date -= 1.day
      else
        break
      end
    end
    
    streak
  end

  def calculate_goal_completion_trend(start_date, end_date)
    # 簡易実装
    sessions = current_user.kpt_sessions.by_date_range(start_date, end_date)
    completed_rate = sessions.count > 0 ? (sessions.completed.count.to_f / sessions.count * 100).round(1) : 0
    
    {
      current_rate: completed_rate,
      trend: completed_rate > 70 ? 'improving' : completed_rate > 40 ? 'stable' : 'declining'
    }
  end

  def calculate_learning_acceleration(start_date, end_date)
    # 簡易実装
    sessions = current_user.kpt_sessions.by_date_range(start_date, end_date)
    items_per_session = sessions.count > 0 ? (sessions.joins(:kpt_items).count.to_f / sessions.count).round(1) : 0
    
    {
      items_per_session: items_per_session,
      acceleration: items_per_session > 5 ? 'fast' : items_per_session > 3 ? 'moderate' : 'slow'
    }
  end
end 