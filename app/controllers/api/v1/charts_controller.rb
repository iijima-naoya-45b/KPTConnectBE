# frozen_string_literal: true

# チャートAPIコントローラー
class Api::V1::ChartsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_chart, only: [ :show, :update, :destroy, :data, :favorite, :reorder ]

  # チャート一覧を取得
  def index
    begin
      charts = current_user.charts.order(:display_order, :created_at)

      # フィルター適用
      charts = charts.where(chart_type: params[:chart_type]) if params[:chart_type].present?
      charts = charts.where(is_favorite: true) if params[:is_favorite] == "true"
      charts = charts.where(is_public: true) if params[:is_public] == "true"

      # ページネーション
      page = params[:page]&.to_i || 1
      per_page = [ params[:per_page]&.to_i || 20, 50 ].min

      total_count = charts.count
      charts = charts.offset((page - 1) * per_page).limit(per_page)

      # データ整形
      charts_data = charts.map { |chart| format_chart_summary(chart) }

      render json: {
        success: true,
        data: {
          charts: charts_data,
          pagination: {
            current_page: page,
            per_page: per_page,
            total_pages: (total_count.to_f / per_page).ceil,
            total_count: total_count
          },
          available_types: get_available_chart_types
        },
        message: "チャート一覧を取得しました"
      }, status: :ok
    rescue StandardError => e
      render json: {
        success: false,
        error: "チャート一覧の取得に失敗しました",
        details: e.message
      }, status: :internal_server_error
    end
  end

  # チャート詳細を取得
  def show
    begin
      chart_data = format_chart_detail(@chart)

      render json: {
        success: true,
        data: chart_data,
        message: "チャート詳細を取得しました"
      }, status: :ok
    rescue StandardError => e
      render json: {
        success: false,
        error: "チャート詳細の取得に失敗しました",
        details: e.message
      }, status: :internal_server_error
    end
  end

  # チャートを作成
  def create
    begin
      @chart = current_user.charts.build(chart_params)

      # 表示順序を設定
      @chart.display_order = current_user.charts.maximum(:display_order).to_i + 1

      if @chart.save
        chart_data = format_chart_detail(@chart)

        render json: {
          success: true,
          data: chart_data,
          message: "チャートを作成しました"
        }, status: :created
      else
        render json: {
          success: false,
          error: "チャートの作成に失敗しました",
          details: @chart.errors.full_messages
        }, status: :unprocessable_entity
      end
    rescue StandardError => e
      render json: {
        success: false,
        error: "チャートの作成中にエラーが発生しました",
        details: e.message
      }, status: :internal_server_error
    end
  end

  # チャートを更新
  def update
    begin
      if @chart.update(chart_params)
        chart_data = format_chart_detail(@chart)

        render json: {
          success: true,
          data: chart_data,
          message: "チャートを更新しました"
        }, status: :ok
      else
        render json: {
          success: false,
          error: "チャートの更新に失敗しました",
          details: @chart.errors.full_messages
        }, status: :unprocessable_entity
      end
    rescue StandardError => e
      render json: {
        success: false,
        error: "チャートの更新中にエラーが発生しました",
        details: e.message
      }, status: :internal_server_error
    end
  end

  # チャートを削除
  def destroy
    begin
      if @chart.destroy
        render json: {
          success: true,
          message: "チャートを削除しました"
        }, status: :ok
      else
        render json: {
          success: false,
          error: "チャートの削除に失敗しました",
          details: @chart.errors.full_messages
        }, status: :unprocessable_entity
      end
    rescue StandardError => e
      render json: {
        success: false,
        error: "チャートの削除中にエラーが発生しました",
        details: e.message
      }, status: :internal_server_error
    end
  end

  # チャートデータを取得
  def data
    begin
      start_date = params[:start_date]&.to_date || 30.days.ago.to_date
      end_date = params[:end_date]&.to_date || Date.current

      chart_data = generate_chart_data(@chart, start_date, end_date)

      render json: {
        success: true,
        data: {
          chart: format_chart_summary(@chart),
          chart_data: chart_data,
          period: {
            start_date: start_date,
            end_date: end_date
          }
        },
        message: "チャートデータを取得しました"
      }, status: :ok
    rescue StandardError => e
      render json: {
        success: false,
        error: "チャートデータの取得に失敗しました",
        details: e.message
      }, status: :internal_server_error
    end
  end

  # お気に入り設定を切り替え
  def favorite
    begin
      @chart.update!(is_favorite: !@chart.is_favorite)

      render json: {
        success: true,
        data: {
          chart: format_chart_summary(@chart),
          is_favorite: @chart.is_favorite
        },
        message: @chart.is_favorite ? "お気に入りに追加しました" : "お気に入りから削除しました"
      }, status: :ok
    rescue StandardError => e
      render json: {
        success: false,
        error: "お気に入り設定の変更に失敗しました",
        details: e.message
      }, status: :internal_server_error
    end
  end

  # チャート並び順を変更
  def reorder
    begin
      chart_ids = params[:chart_ids]

      if chart_ids.blank? || !chart_ids.is_a?(Array)
        render json: {
          success: false,
          error: "チャートIDの配列を指定してください"
        }, status: :unprocessable_entity
        return
      end

      # トランザクション内で並び順を更新
      ActiveRecord::Base.transaction do
        chart_ids.each_with_index do |chart_id, index|
          chart = current_user.charts.find(chart_id)
          chart.update!(display_order: index + 1)
        end
      end

      render json: {
        success: true,
        message: "チャートの並び順を更新しました"
      }, status: :ok
    rescue ActiveRecord::RecordNotFound
      render json: {
        success: false,
        error: "指定されたチャートが見つかりません"
      }, status: :not_found
    rescue StandardError => e
      render json: {
        success: false,
        error: "チャート並び順の変更に失敗しました",
        details: e.message
      }, status: :internal_server_error
    end
  end

  private

  # チャートを設定
  def set_chart
    @chart = current_user.charts.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: {
      success: false,
      error: "チャートが見つかりません"
    }, status: :not_found
  end

  # チャートパラメーターを許可
  def chart_params
    params.require(:chart).permit(
      :name, :description, :chart_type, :is_public, :is_favorite,
      config: {},
      data_query: {}
    )
  end

  # チャートサマリーを整形
  def format_chart_summary(chart)
    {
      id: chart.id,
      name: chart.name,
      description: chart.description,
      chart_type: chart.chart_type,
      is_public: chart.is_public,
      is_favorite: chart.is_favorite,
      display_order: chart.display_order,
      created_at: chart.created_at,
      updated_at: chart.updated_at
    }
  end

  # チャート詳細を整形
  def format_chart_detail(chart)
    {
      id: chart.id,
      name: chart.name,
      description: chart.description,
      chart_type: chart.chart_type,
      config: chart.config,
      data_query: chart.data_query,
      is_public: chart.is_public,
      is_favorite: chart.is_favorite,
      display_order: chart.display_order,
      created_at: chart.created_at,
      updated_at: chart.updated_at
    }
  end

  # 利用可能なチャートタイプを取得
  def get_available_chart_types
    [
      { type: "line", name: "折れ線グラフ", description: "時系列データの表示に適している" },
      { type: "bar", name: "棒グラフ", description: "カテゴリ別データの比較に適している" },
      { type: "pie", name: "円グラフ", description: "割合の表示に適している" },
      { type: "area", name: "エリアチャート", description: "累積データの表示に適している" },
      { type: "scatter", name: "散布図", description: "相関関係の表示に適している" },
      { type: "heatmap", name: "ヒートマップ", description: "密度や強度の表示に適している" },
      { type: "treemap", name: "ツリーマップ", description: "階層データの表示に適している" }
    ]
  end

  # チャートデータを生成
  def generate_chart_data(chart, start_date, end_date)
    case chart.chart_type
    when "line"
      generate_line_chart_data(chart, start_date, end_date)
    when "bar"
      generate_bar_chart_data(chart, start_date, end_date)
    when "pie"
      generate_pie_chart_data(chart, start_date, end_date)
    when "area"
      generate_area_chart_data(chart, start_date, end_date)
    when "scatter"
      generate_scatter_chart_data(chart, start_date, end_date)
    when "heatmap"
      generate_heatmap_chart_data(chart, start_date, end_date)
    when "treemap"
      generate_treemap_chart_data(chart, start_date, end_date)
    else
      { error: "未対応のチャートタイプです" }
    end
  end

  # 折れ線グラフデータを生成
  def generate_line_chart_data(chart, start_date, end_date)
    query_type = chart.data_query["query_type"]

    case query_type
    when "kpt_sessions_trend"
      sessions_by_date = current_user.kpt_sessions
                                    .where(session_date: start_date..end_date)
                                    .group_by_day(:session_date)
                                    .count

      {
        labels: (start_date..end_date).map(&:to_s),
        datasets: [ {
          label: "KPTセッション数",
          data: (start_date..end_date).map { |date| sessions_by_date[date] || 0 },
          borderColor: "rgb(99, 102, 241)",
          backgroundColor: "rgba(99, 102, 241, 0.1)"
        } ]
      }
    when "emotion_trend"
      emotion_data = current_user.kpt_items
                                 .joins(:kpt_session)
                                 .where(kpt_sessions: { session_date: start_date..end_date })
                                 .where.not(emotion_score: nil)
                                 .group_by_day("kpt_sessions.session_date")
                                 .average(:emotion_score)

      {
        labels: (start_date..end_date).map(&:to_s),
        datasets: [ {
          label: "感情スコア平均",
          data: (start_date..end_date).map { |date| emotion_data[date]&.round(2) || 0 },
          borderColor: "rgb(244, 63, 94)",
          backgroundColor: "rgba(244, 63, 94, 0.1)"
        } ]
      }
    else
      generate_default_line_data(start_date, end_date)
    end
  end

  # 棒グラフデータを生成
  def generate_bar_chart_data(chart, start_date, end_date)
    query_type = chart.data_query["query_type"]

    case query_type
    when "kpt_items_by_type"
      items_data = current_user.kpt_items
                              .joins(:kpt_session)
                              .where(kpt_sessions: { session_date: start_date..end_date })
                              .group(:type)
                              .count

      {
        labels: [ "Keep", "Problem", "Try" ],
        datasets: [ {
          label: "アイテム数",
          data: [ items_data["keep"] || 0, items_data["problem"] || 0, items_data["try"] || 0 ],
          backgroundColor: [ "rgba(34, 197, 94, 0.8)", "rgba(239, 68, 68, 0.8)", "rgba(59, 130, 246, 0.8)" ]
        } ]
      }
    when "productivity_by_category"
      work_logs_data = current_user.work_logs
                                  .where(started_at: start_date..end_date.end_of_day)
                                  .group(:category)
                                  .average(:productivity_score)

      {
        labels: work_logs_data.keys,
        datasets: [ {
          label: "生産性スコア平均",
          data: work_logs_data.values.map { |v| v&.round(2) || 0 },
          backgroundColor: "rgba(99, 102, 241, 0.8)"
        } ]
      }
    else
      generate_default_bar_data
    end
  end

  # 円グラフデータを生成
  def generate_pie_chart_data(chart, start_date, end_date)
    query_type = chart.data_query["query_type"]

    case query_type
    when "sessions_by_status"
      status_data = current_user.kpt_sessions
                               .where(session_date: start_date..end_date)
                               .group(:status)
                               .count

      {
        labels: status_data.keys.map { |status| status_name_ja(status) },
        datasets: [ {
          data: status_data.values,
          backgroundColor: [
            "rgba(34, 197, 94, 0.8)",   # completed
            "rgba(99, 102, 241, 0.8)",  # in_progress
            "rgba(156, 163, 175, 0.8)",  # draft
            "rgba(75, 85, 99, 0.8)"     # archived
          ]
        } ]
      }
    else
      generate_default_pie_data
    end
  end

  # その他のチャートタイプのデフォルトデータ生成メソッド
  def generate_area_chart_data(chart, start_date, end_date)
    generate_line_chart_data(chart, start_date, end_date)
  end

  def generate_scatter_chart_data(chart, start_date, end_date)
    items = current_user.kpt_items
                       .joins(:kpt_session)
                       .where(kpt_sessions: { session_date: start_date..end_date })
                       .where.not(emotion_score: nil, impact_score: nil)

    {
      datasets: [ {
        label: "KPTアイテム",
        data: items.map { |item| { x: item.emotion_score, y: item.impact_score } },
        backgroundColor: "rgba(99, 102, 241, 0.6)"
      } ]
    }
  end

  def generate_heatmap_chart_data(chart, start_date, end_date)
    # ヒートマップの簡易実装
    sessions_by_weekday_hour = current_user.kpt_sessions
                                          .where(session_date: start_date..end_date)
                                          .group_by_day_of_week(:created_at)
                                          .group_by_hour(:created_at)
                                          .count

    { heatmap_data: sessions_by_weekday_hour }
  end

  def generate_treemap_chart_data(chart, start_date, end_date)
    tags_data = current_user.kpt_items
                           .joins(:kpt_session)
                           .where(kpt_sessions: { session_date: start_date..end_date })
                           .where.not(tags: [])
                           .pluck(:tags)
                           .flatten
                           .tally

    {
      datasets: [ {
        tree: tags_data.map { |tag, count| { name: tag, value: count } },
        backgroundColor: "rgba(99, 102, 241, 0.8)"
      } ]
    }
  end

  # デフォルトデータ生成メソッド
  def generate_default_line_data(start_date, end_date)
    {
      labels: (start_date..end_date).map(&:to_s),
      datasets: [ {
        label: "サンプルデータ",
        data: (start_date..end_date).map { rand(10) },
        borderColor: "rgb(99, 102, 241)"
      } ]
    }
  end

  def generate_default_bar_data
    {
      labels: [ "カテゴリA", "カテゴリB", "カテゴリC" ],
      datasets: [ {
        label: "サンプルデータ",
        data: [ 10, 20, 15 ],
        backgroundColor: "rgba(99, 102, 241, 0.8)"
      } ]
    }
  end

  def generate_default_pie_data
    {
      labels: [ "項目1", "項目2", "項目3" ],
      datasets: [ {
        data: [ 30, 40, 30 ],
        backgroundColor: [ "rgba(34, 197, 94, 0.8)", "rgba(239, 68, 68, 0.8)", "rgba(59, 130, 246, 0.8)" ]
      } ]
    }
  end

  # ステータス名の日本語変換
  def status_name_ja(status)
    case status
    when "draft"
      "下書き"
    when "in_progress"
      "進行中"
    when "completed"
      "完了"
    when "archived"
      "アーカイブ済み"
    else
      status
    end
  end
end
