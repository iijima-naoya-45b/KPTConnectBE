# frozen_string_literal: true

# インサイトAPIコントローラー
class Api::V1::InsightsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_insight, only: [ :show, :update, :destroy ]

  # インサイト一覧を取得
  def index
    begin
      insights = current_user.insights.order(created_at: :desc)

      # フィルター適用
      insights = insights.where(insight_type: params[:type]) if params[:type].present?

      # ページネーション
      page = params[:page]&.to_i || 1
      per_page = [ params[:per_page]&.to_i || 20, 50 ].min

      total_count = insights.count
      insights = insights.offset((page - 1) * per_page).limit(per_page)

      # データ整形
      insights_data = insights.map { |insight| format_insight_summary(insight) }

      render json: {
        success: true,
        data: {
          insights: insights_data,
          pagination: {
            current_page: page,
            per_page: per_page,
            total_pages: (total_count.to_f / per_page).ceil,
            total_count: total_count
          }
        },
        message: "インサイト一覧を取得しました"
      }, status: :ok
    rescue StandardError => e
      render json: {
        success: false,
        error: "インサイト一覧の取得に失敗しました",
        details: e.message
      }, status: :internal_server_error
    end
  end

  # インサイト詳細を取得
  def show
    begin
      insight_data = format_insight_detail(@insight)

      render json: {
        success: true,
        data: insight_data,
        message: "インサイト詳細を取得しました"
      }, status: :ok
    rescue StandardError => e
      render json: {
        success: false,
        error: "インサイト詳細の取得に失敗しました",
        details: e.message
      }, status: :internal_server_error
    end
  end

  # インサイトを生成
  def generate
    begin
      analysis_type = params[:analysis_type] || "comprehensive"
      options = params[:options] || {}

      case analysis_type
      when "emotion_analysis"
        insight_data = generate_emotion_insights(options)
      when "productivity_analysis"
        insight_data = generate_productivity_insights(options)
      when "pattern_analysis"
        insight_data = generate_pattern_insights(options)
      when "comprehensive"
        insight_data = generate_comprehensive_insights(options)
      else
        render json: {
          success: false,
          error: "無効な分析タイプです"
        }, status: :unprocessable_entity
        return
      end

      # インサイトをデータベースに保存
      insight = current_user.insights.create!(
        insight_type: analysis_type,
        data: insight_data,
        generated_at: Time.current
      )

      render json: {
        success: true,
        data: format_insight_detail(insight),
        message: "インサイトを生成しました"
      }, status: :created
    rescue StandardError => e
      render json: {
        success: false,
        error: "インサイトの生成に失敗しました",
        details: e.message
      }, status: :internal_server_error
    end
  end

  # パターン分析を取得
  def patterns
    begin
      days = params[:days]&.to_i || 30
      days = [ days, 365 ].min

      patterns_data = {
        recurring_themes: analyze_recurring_themes(days),
        success_patterns: analyze_success_patterns(days),
        problem_patterns: analyze_problem_patterns(days),
        time_patterns: analyze_time_patterns(days),
        tag_correlations: analyze_tag_correlations(days)
      }

      render json: {
        success: true,
        data: patterns_data,
        period_days: days,
        message: "#{days}日間のパターン分析を完了しました"
      }, status: :ok
    rescue StandardError => e
      render json: {
        success: false,
        error: "パターン分析に失敗しました",
        details: e.message
      }, status: :internal_server_error
    end
  end

  # 改善提案を取得
  def recommendations
    begin
      recommendations_data = {
        immediate_actions: generate_immediate_recommendations,
        long_term_suggestions: generate_long_term_recommendations,
        process_improvements: generate_process_recommendations,
        goal_suggestions: generate_goal_recommendations
      }

      render json: {
        success: true,
        data: recommendations_data,
        message: "改善提案を生成しました"
      }, status: :ok
    rescue StandardError => e
      render json: {
        success: false,
        error: "改善提案の生成に失敗しました",
        details: e.message
      }, status: :internal_server_error
    end
  end

  private

  # インサイトを設定
  def set_insight
    @insight = current_user.insights.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: {
      success: false,
      error: "インサイトが見つかりません"
    }, status: :not_found
  end

  # インサイトサマリーを整形
  def format_insight_summary(insight)
    {
      id: insight.id,
      insight_type: insight.insight_type,
      title: insight.data.dig("title") || "#{insight.insight_type}分析",
      summary: insight.data.dig("summary") || "分析結果",
      generated_at: insight.generated_at,
      created_at: insight.created_at
    }
  end

  # インサイト詳細を整形
  def format_insight_detail(insight)
    {
      id: insight.id,
      insight_type: insight.insight_type,
      data: insight.data,
      generated_at: insight.generated_at,
      created_at: insight.created_at,
      updated_at: insight.updated_at
    }
  end

  # 感情分析インサイトを生成
  def generate_emotion_insights(options)
    emotion_trend = KptItem.emotion_trend(current_user, 30)

    {
      title: "感情スコア分析",
      summary: "過去30日間の感情スコアの傾向を分析しました",
      analysis: {
        average_score: emotion_trend[:overall_average],
        trend_direction: emotion_trend[:trend_direction],
        daily_averages: emotion_trend[:daily_averages]
      },
      insights: generate_emotion_insights_text(emotion_trend),
      recommendations: generate_emotion_recommendations(emotion_trend)
    }
  end

  # 生産性分析インサイトを生成
  def generate_productivity_insights(options)
    completion_rate = calculate_completion_rate

    {
      title: "生産性分析",
      summary: "KPTアイテムの完了率と生産性を分析しました",
      analysis: {
        completion_rate: completion_rate,
        productivity_score: calculate_productivity_score,
        weekly_trends: calculate_weekly_productivity_trends
      },
      insights: generate_productivity_insights_text(completion_rate),
      recommendations: generate_productivity_recommendations(completion_rate)
    }
  end

  # パターン分析インサイトを生成
  def generate_pattern_insights(options)
    {
      title: "パターン分析",
      summary: "KPTデータからパターンを発見しました",
      analysis: {
        recurring_themes: analyze_recurring_themes(30),
        success_patterns: analyze_success_patterns(30)
      },
      insights: [ "定期的な振り返りが効果的です", "タグ付けによる分類が有効です" ],
      recommendations: [ "週次でのKPT実施を推奨します" ]
    }
  end

  # 包括的インサイトを生成
  def generate_comprehensive_insights(options)
    {
      title: "総合分析",
      summary: "KPTデータの包括的な分析を行いました",
      analysis: {
        emotion: generate_emotion_insights(options)[:analysis],
        productivity: generate_productivity_insights(options)[:analysis],
        patterns: generate_pattern_insights(options)[:analysis]
      },
      key_insights: [
        "感情スコアの向上傾向が見られます",
        "問題解決のパターンが確立されています",
        "継続的な改善が実現されています"
      ],
      action_items: [
        "高優先度のTryアイテムに集中してください",
        "定期的な振り返りを継続してください"
      ]
    }
  end

  # 繰り返しテーマを分析
  def analyze_recurring_themes(days)
    popular_tags = KptItem.popular_tags(current_user, nil, 10)
    popular_tags.select { |tag_data| tag_data[:count] >= 3 }
  end

  # 成功パターンを分析
  def analyze_success_patterns(days)
    completed_items = current_user.kpt_items.completed
                                  .where("completed_at >= ?", days.days.ago)

    successful_patterns = completed_items.group(:type).average(:impact_score)
    successful_patterns.map do |type, avg_impact|
      {
        type: type,
        average_impact: avg_impact&.round(2),
        success_indicator: avg_impact && avg_impact > 3.5 ? "high" : "medium"
      }
    end
  end

  # 問題パターンを分析
  def analyze_problem_patterns(days)
    overdue_items = current_user.kpt_items.overdue

    {
      overdue_count: overdue_items.count,
      common_types: overdue_items.group(:type).count,
      avg_emotion_score: overdue_items.with_emotion_score.average(:emotion_score)&.round(2)
    }
  end

  # 時間パターンを分析
  def analyze_time_patterns(days)
    sessions = current_user.kpt_sessions.where("created_at >= ?", days.days.ago)

    {
      weekly_distribution: sessions.group_by_day_of_week(:created_at).count,
      monthly_trends: sessions.group_by_month(:created_at).count
    }
  end

  # タグ相関を分析
  def analyze_tag_correlations(days)
    # 簡単な相関分析（実際のAI分析ではより高度な手法を使用）
    items = current_user.kpt_items.where("created_at >= ?", days.days.ago)
    tag_combinations = []

    items.each do |item|
      next if item.tags.size < 2

      item.tags.combination(2).each do |tag_pair|
        tag_combinations << tag_pair.sort
      end
    end

    tag_combinations.tally.sort_by { |_, count| -count }.first(5)
  end

  # その他のヘルパーメソッド
  def generate_emotion_insights_text(emotion_trend)
    insights = []

    if emotion_trend[:trend_direction] == "up"
      insights << "感情スコアが向上傾向にあります"
    elsif emotion_trend[:trend_direction] == "down"
      insights << "感情スコアの低下が見られます。ストレス要因を確認してください"
    else
      insights << "感情スコアは安定しています"
    end

    insights
  end

  def generate_emotion_recommendations(emotion_trend)
    recommendations = []

    if emotion_trend[:overall_average] && emotion_trend[:overall_average] < 3.0
      recommendations << "ポジティブな要素を増やすことを推奨します"
    end

    recommendations << "定期的な感情スコアの記録を継続してください"
    recommendations
  end

  def generate_productivity_insights_text(completion_rate)
    if completion_rate > 70
      [ "高い完了率を維持しています" ]
    elsif completion_rate > 50
      [ "適度な完了率です。さらなる向上の余地があります" ]
    else
      [ "完了率の改善が必要です" ]
    end
  end

  def generate_productivity_recommendations(completion_rate)
    recommendations = []

    if completion_rate < 50
      recommendations << "アイテムの優先順位を見直してください"
      recommendations << "より具体的で実行可能なアイテムに分割してください"
    end

    recommendations << "定期的な進捗確認を行ってください"
    recommendations
  end

  def calculate_completion_rate
    total_items = current_user.kpt_items.count
    return 0.0 if total_items.zero?

    completed_items = current_user.kpt_items.completed.count
    (completed_items.to_f / total_items * 100).round(2)
  end

  def calculate_productivity_score
    # 生産性スコアの計算ロジック（簡略版）
    completion_rate = calculate_completion_rate
    recent_activity = current_user.kpt_sessions.where("created_at >= ?", 7.days.ago).count

    [ (completion_rate + recent_activity * 10), 100 ].min.round(2)
  end

  def calculate_weekly_productivity_trends
    (0..3).map do |week_offset|
      week_start = week_offset.weeks.ago.beginning_of_week
      week_end = week_offset.weeks.ago.end_of_week

      week_items = current_user.kpt_items.where(created_at: week_start..week_end)
      completed_count = week_items.completed.count
      total_count = week_items.count

      {
        week: week_start.strftime("%m/%d"),
        completion_rate: total_count > 0 ? (completed_count.to_f / total_count * 100).round(2) : 0
      }
    end.reverse
  end

  def generate_immediate_recommendations
    [
      "期限切れのアイテムを優先的に処理してください",
      "高優先度のTryアイテムに着手してください",
      "感情スコアの低いアイテムの原因を分析してください"
    ]
  end

  def generate_long_term_recommendations
    [
      "定期的なKPTセッションの実施を継続してください",
      "アイテムのタグ付けを活用してパターンを把握してください",
      "月次でのレトロスペクティブを実施してください"
    ]
  end

  def generate_process_recommendations
    [
      "KPTアイテムの粒度を適切に保ってください",
      "セッション終了時には必ず次のアクションを決めてください",
      "定量的な目標設定を心がけてください"
    ]
  end

  def generate_goal_recommendations
    [
      "週次での完了率70%を目指してください",
      "感情スコア3.5以上の維持を目標にしてください",
      "月間5セッション以上の実施を推奨します"
    ]
  end
end
