# frozen_string_literal: true

# KPTアイテムAPIコントローラー
#
# @description KPTアイテムのCRUD操作を提供
# アイテムの作成、更新、削除、ステータス管理、
# アイテム統計などの機能を実装
#
# @endpoints
# - GET /api/v1/kpt_items アイテム一覧
# - GET /api/v1/kpt_items/:id アイテム詳細
# - POST /api/v1/kpt_items アイテム作成
# - PUT /api/v1/kpt_items/:id アイテム更新
# - DELETE /api/v1/kpt_items/:id アイテム削除
# - POST /api/v1/kpt_items/:id/complete アイテム完了
# - PUT /api/v1/kpt_items/:id/update_status ステータス更新
class Api::V1::KptItemsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_kpt_item, only: [:show, :update, :destroy, :complete, :update_status]

  # アイテム一覧を取得
  # @route GET /api/v1/kpt_items
  # @param [String] type アイテムタイプフィルター (keep, problem, try)
  # @param [String] status ステータスフィルター
  # @param [String] priority 優先度フィルター
  # @param [String] tag タグフィルター
  # @param [UUID] kpt_session_id セッションIDフィルター
  # @param [Integer] page ページ番号
  # @param [Integer] per_page 1ページあたりの件数
  # @response [JSON] アイテム一覧
  def index
    begin
      items = current_user.kpt_items.includes(:kpt_session)

      # フィルター適用
      items = items.where(type: params[:type]) if params[:type].present?
      items = items.by_status(params[:status]) if params[:status].present?
      items = items.by_priority(params[:priority]) if params[:priority].present?
      items = items.with_tag(params[:tag]) if params[:tag].present?
      items = items.where(kpt_session_id: params[:kpt_session_id]) if params[:kpt_session_id].present?

      # ソート
      items = items.recent

      # ページネーション
      page = params[:page]&.to_i || 1
      per_page = [params[:per_page]&.to_i || 20, 100].min

      total_count = items.count
      items = items.offset((page - 1) * per_page).limit(per_page)

      # データ整形
      items_data = items.map { |item| format_kpt_item_summary(item) }

      render json: {
        success: true,
        data: {
          items: items_data,
          pagination: {
            current_page: page,
            per_page: per_page,
            total_pages: (total_count.to_f / per_page).ceil,
            total_count: total_count
          }
        },
        message: 'アイテム一覧を取得しました'
      }, status: :ok
    rescue StandardError => e
      Rails.logger.error "KPT items index error: #{e.message}"
      render json: {
        success: false,
        error: 'アイテム一覧の取得に失敗しました',
        details: e.message
      }, status: :internal_server_error
    end
  end

  # アイテム詳細を取得
  # @route GET /api/v1/kpt_items/:id
  # @response [JSON] アイテム詳細
  def show
    begin
      item_data = format_kpt_item_detail(@kpt_item)

      render json: {
        success: true,
        data: item_data,
        message: 'アイテム詳細を取得しました'
      }, status: :ok
    rescue StandardError => e
      Rails.logger.error "KPT item show error: #{e.message}"
      render json: {
        success: false,
        error: 'アイテム詳細の取得に失敗しました',
        details: e.message
      }, status: :internal_server_error
    end
  end

  # アイテムを作成
  # @route POST /api/v1/kpt_items
  # @param [Hash] item アイテムデータ
  # @response [JSON] 作成されたアイテム
  def create
    begin
      kpt_session = current_user.kpt_sessions.find(params[:item][:kpt_session_id])
      @kpt_item = kpt_session.kpt_items.build(item_params)

      if @kpt_item.save
        item_data = format_kpt_item_detail(@kpt_item)

        render json: {
          success: true,
          data: item_data,
          message: 'アイテムを作成しました'
        }, status: :created
      else
        render json: {
          success: false,
          error: 'アイテムの作成に失敗しました',
          details: @kpt_item.errors.full_messages
        }, status: :unprocessable_entity
      end
    rescue ActiveRecord::RecordNotFound
      render json: {
        success: false,
        error: 'セッションが見つかりません'
      }, status: :not_found
    rescue StandardError => e
      Rails.logger.error "KPT item create error: #{e.message}"
      render json: {
        success: false,
        error: 'アイテムの作成中にエラーが発生しました',
        details: e.message
      }, status: :internal_server_error
    end
  end

  # アイテムを更新
  # @route PUT /api/v1/kpt_items/:id
  # @param [Hash] item アイテムデータ
  # @response [JSON] 更新されたアイテム
  def update
    begin
      if @kpt_item.update(item_params)
        item_data = format_kpt_item_detail(@kpt_item)

        render json: {
          success: true,
          data: item_data,
          message: 'アイテムを更新しました'
        }, status: :ok
      else
        render json: {
          success: false,
          error: 'アイテムの更新に失敗しました',
          details: @kpt_item.errors.full_messages
        }, status: :unprocessable_entity
      end
    rescue StandardError => e
      Rails.logger.error "KPT item update error: #{e.message}"
      render json: {
        success: false,
        error: 'アイテムの更新中にエラーが発生しました',
        details: e.message
      }, status: :internal_server_error
    end
  end

  # アイテムを削除
  # @route DELETE /api/v1/kpt_items/:id
  # @response [JSON] 削除結果
  def destroy
    begin
      if @kpt_item.destroy
        render json: {
          success: true,
          message: 'アイテムを削除しました'
        }, status: :ok
      else
        render json: {
          success: false,
          error: 'アイテムの削除に失敗しました',
          details: @kpt_item.errors.full_messages
        }, status: :unprocessable_entity
      end
    rescue StandardError => e
      Rails.logger.error "KPT item destroy error: #{e.message}"
      render json: {
        success: false,
        error: 'アイテムの削除中にエラーが発生しました',
        details: e.message
      }, status: :internal_server_error
    end
  end

  # アイテムを完了
  # @route POST /api/v1/kpt_items/:id/complete
  # @response [JSON] 完了結果
  def complete
    begin
      if @kpt_item.update(status: 'completed')
        item_data = format_kpt_item_detail(@kpt_item)

        render json: {
          success: true,
          data: item_data,
          message: 'アイテムを完了しました'
        }, status: :ok
      else
        render json: {
          success: false,
          error: 'アイテムの完了に失敗しました',
          details: @kpt_item.errors.full_messages
        }, status: :unprocessable_entity
      end
    rescue StandardError => e
      Rails.logger.error "KPT item complete error: #{e.message}"
      render json: {
        success: false,
        error: 'アイテム完了処理中にエラーが発生しました',
        details: e.message
      }, status: :internal_server_error
    end
  end

  # アイテムステータスを更新
  # @route PUT /api/v1/kpt_items/:id/update_status
  # @param [String] status 新しいステータス
  # @response [JSON] 更新結果
  def update_status
    begin
      new_status = params[:status]
      
      if new_status.blank?
        render json: {
          success: false,
          error: 'ステータスを指定してください'
        }, status: :unprocessable_entity
        return
      end

      if @kpt_item.update(status: new_status)
        item_data = format_kpt_item_detail(@kpt_item)

        render json: {
          success: true,
          data: item_data,
          message: 'ステータスを更新しました'
        }, status: :ok
      else
        render json: {
          success: false,
          error: 'ステータスの更新に失敗しました',
          details: @kpt_item.errors.full_messages
        }, status: :unprocessable_entity
      end
    rescue StandardError => e
      Rails.logger.error "KPT item update_status error: #{e.message}"
      render json: {
        success: false,
        error: 'ステータス更新中にエラーが発生しました',
        details: e.message
      }, status: :internal_server_error
    end
  end

  # アイテム統計を取得
  # @route GET /api/v1/kpt_items/stats
  # @param [Date] start_date 開始日
  # @param [Date] end_date 終了日
  # @param [String] type アイテムタイプフィルター
  # @response [JSON] アイテム統計
  def stats
    begin
      start_date = params[:start_date]&.to_date || 30.days.ago.to_date
      end_date = params[:end_date]&.to_date || Date.current

      stats_data = KptItem.type_stats(current_user, start_date, end_date)
      
      # 追加統計
      additional_stats = {
        period: {
          start_date: start_date,
          end_date: end_date
        },
        distribution: KptItem.impact_distribution(current_user),
        popular_tags: KptItem.popular_tags(current_user, params[:type], 10),
        emotion_trend: KptItem.emotion_trend(current_user, (end_date - start_date).to_i)
      }

      render json: {
        success: true,
        data: {
          type_stats: stats_data,
          **additional_stats
        },
        message: 'アイテム統計を取得しました'
      }, status: :ok
    rescue StandardError => e
      Rails.logger.error "KPT item stats error: #{e.message}"
      render json: {
        success: false,
        error: '統計データの取得に失敗しました',
        details: e.message
      }, status: :internal_server_error
    end
  end

  # アイテム傾向分析を取得
  # @route GET /api/v1/kpt_items/trends
  # @param [Integer] days 分析期間（日数）
  # @response [JSON] 傾向分析データ
  def trends
    begin
      days = params[:days]&.to_i || 30
      days = [days, 365].min # 最大1年
      days = 7 if days < 7    # 最小1週間

      trends_data = {
        emotion_trend: KptItem.emotion_trend(current_user, days),
        impact_distribution: KptItem.impact_distribution(current_user),
        completion_trend: calculate_completion_trend(days),
        priority_distribution: calculate_priority_distribution(days)
      }

      render json: {
        success: true,
        data: trends_data,
        period_days: days,
        message: "#{days}日間の傾向分析を取得しました"
      }, status: :ok
    rescue StandardError => e
      Rails.logger.error "KPT item trends error: #{e.message}"
      render json: {
        success: false,
        error: '傾向分析の取得に失敗しました',
        details: e.message
      }, status: :internal_server_error
    end
  end

  private

  # KPTアイテムを設定
  def set_kpt_item
    @kpt_item = current_user.kpt_items.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: {
      success: false,
      error: 'アイテムが見つかりません'
    }, status: :not_found
  end

  # アイテムパラメーターを許可
  def item_params
    params.require(:item).permit(
      :kpt_session_id, :type, :content, :priority, :status, :due_date, :assigned_to,
      :emotion_score, :impact_score, :notes,
      tags: []
    )
  end

  # アイテムサマリーを整形
  # @param [KptItem] item アイテム
  # @return [Hash] 整形されたサマリーデータ
  def format_kpt_item_summary(item)
    {
      id: item.id,
      type: item.type,
      content: item.content.truncate(100),
      priority: item.priority,
      status: item.status,
      due_date: item.due_date,
      assigned_to: item.assigned_to,
      emotion_score: item.emotion_score,
      impact_score: item.impact_score,
      tags: item.tags,
      importance_score: item.importance_score,
      session: {
        id: item.kpt_session.id,
        title: item.kpt_session.title,
        session_date: item.kpt_session.session_date
      },
      created_at: item.created_at,
      updated_at: item.updated_at,
      completed_at: item.completed_at
    }
  end

  # アイテム詳細を整形
  # @param [KptItem] item アイテム
  # @return [Hash] 整形された詳細データ
  def format_kpt_item_detail(item)
    {
      id: item.id,
      type: item.type,
      type_name_ja: item.type_name_ja,
      content: item.content,
      priority: item.priority,
      priority_name_ja: item.priority_name_ja,
      status: item.status,
      status_name_ja: item.status_name_ja,
      due_date: item.due_date,
      assigned_to: item.assigned_to,
      emotion_score: item.emotion_score,
      impact_score: item.impact_score,
      tags: item.tags,
      notes: item.notes,
      importance_score: item.importance_score,
      is_overdue: item.overdue?,
      is_due_soon: item.due_soon?,
      session: {
        id: item.kpt_session.id,
        title: item.kpt_session.title,
        description: item.kpt_session.description,
        session_date: item.kpt_session.session_date,
        status: item.kpt_session.status
      },
      similar_items: item.similar_items.map { |similar| format_similar_item(similar) },
      created_at: item.created_at,
      updated_at: item.updated_at,
      completed_at: item.completed_at
    }
  end

  # 類似アイテムを整形
  # @param [KptItem] item アイテム
  # @return [Hash] 整形された類似アイテムデータ
  def format_similar_item(item)
    {
      id: item.id,
      content: item.content.truncate(50),
      type: item.type,
      session_title: item.kpt_session.title,
      created_at: item.created_at
    }
  end

  # 完了傾向を計算
  # @param [Integer] days 分析期間
  # @return [Hash] 完了傾向データ
  def calculate_completion_trend(days)
    start_date = days.days.ago.to_date
    items = current_user.kpt_items.joins(:kpt_session)
                        .where(kpt_sessions: { session_date: start_date..Date.current })

    weekly_data = []
    weeks = (days / 7.0).ceil

    (0...weeks).each do |i|
      week_start = (i * 7).days.ago.to_date
      week_end = ((i * 7) - 6).days.ago.to_date
      week_items = items.where(created_at: week_end..week_start.end_of_day)
      
      weekly_data << {
        week: "#{week_end.strftime('%m/%d')}-#{week_start.strftime('%m/%d')}",
        total: week_items.count,
        completed: week_items.completed.count,
        completion_rate: week_items.count > 0 ? (week_items.completed.count.to_f / week_items.count * 100).round(2) : 0
      }
    end

    {
      weekly_data: weekly_data.reverse,
      overall_completion_rate: items.count > 0 ? (items.completed.count.to_f / items.count * 100).round(2) : 0
    }
  end

  # 優先度分布を計算
  # @param [Integer] days 分析期間
  # @return [Hash] 優先度分布データ
  def calculate_priority_distribution(days)
    start_date = days.days.ago.to_date
    items = current_user.kpt_items.joins(:kpt_session)
                        .where(kpt_sessions: { session_date: start_date..Date.current })

    distribution = items.group(:priority).group(:status).count
    
    {
      distribution: distribution,
      summary: {
        high_priority: items.high_priority.count,
        medium_priority: items.where(priority: 'medium').count,
        low_priority: items.where(priority: 'low').count
      }
    }
  end
end 