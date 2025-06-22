# frozen_string_literal: true

# KPTアイテムAPIコントローラー
class Api::V1::KptItemsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_kpt_item, only: [ :show, :update, :destroy, :complete, :reopen, :move, :copy, :link_work_log, :unlink_work_log ]

  # KPTアイテム一覧を取得
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
      per_page = [ params[:per_page]&.to_i || 20, 100 ].min

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
        message: "アイテム一覧を取得しました"
      }, status: :ok
    rescue StandardError => e
      render_error(error: "KPT項目一覧の取得中にエラーが発生しました", status: :internal_server_error)
    end
  end

  # アイテム詳細を取得
  def show
    begin
      item_data = format_kpt_item_detail(@kpt_item)

      render json: {
        success: true,
        data: item_data,
        message: "アイテム詳細を取得しました"
      }, status: :ok
    rescue StandardError => e
      render_error(error: "アイテム詳細の取得に失敗しました", status: :internal_server_error)
    end
  end

  # アイテムを作成
  def create
    begin
      kpt_session = current_user.kpt_sessions.last
      unless kpt_session
        kpt_session = current_user.kpt_sessions.create!(
          session_date: Date.current,
          title: "GitHub Issues Import - #{Time.current.strftime('%Y-%m-%d %H:%M')}"
        )
      end
      @kpt_item = kpt_session.kpt_items.build(
        type: params[:item][:type],
        content: params[:item][:content],
        status: params[:item][:status],
        priority: params[:item][:priority],
        notes: params[:item][:notes],
        external_repo: params[:item][:external_repo],
        external_number: params[:item][:external_number],
        external_url: params[:item][:external_url]
      )

      puts "status: #{@kpt_item.status.inspect} (#{@kpt_item.status.class})"
      puts "type: #{@kpt_item.type.inspect} (#{@kpt_item.type.class})"
      unless @kpt_item.valid?
        puts "Validation errors (valid?): #{@kpt_item.errors.full_messages.inspect}"
      end

      if @kpt_item.save
        item_data = format_kpt_item_detail(@kpt_item)

        render json: {
          success: true,
          data: item_data,
          message: "アイテムを作成しました"
        }, status: :created
      else
        render json: {
          success: false,
          error: "アイテムの作成に失敗しました",
          details: @kpt_item.errors.full_messages
        }, status: :unprocessable_entity
      end
    rescue ActiveRecord::RecordNotFound => e
      render json: {
        success: false,
        error: "セッションが見つかりません"
      }, status: :not_found
    rescue StandardError => e
      render_error(error: "アイテムの作成中にエラーが発生しました", status: :internal_server_error)
    end
  end

  # アイテムを更新
  def update
    begin
      if @kpt_item.update(kpt_item_params)
        render json: { success: true, message: "アイテムを更新しました" }, status: :ok
      else
        render json: {
          success: false,
          error: "アイテムの更新に失敗しました",
          details: @kpt_item.errors.full_messages
        }, status: :unprocessable_entity
      end
    rescue StandardError => e
      render_error(error: "アイテムの更新中にエラーが発生しました", status: :internal_server_error)
    end
  end

  # アイテムを削除
  def destroy
    begin
      if @kpt_item.destroy
        render json: {
          success: true,
          message: "アイテムを削除しました"
        }, status: :ok
      else
        render json: {
          success: false,
          error: "アイテムの削除に失敗しました",
          details: @kpt_item.errors.full_messages
        }, status: :unprocessable_entity
      end
    rescue StandardError => e
      render_error(error: "アイテムの削除中にエラーが発生しました", status: :internal_server_error)
    end
  end

  # アイテムを完了
  def complete
    begin
      if @kpt_item.update(status: "completed")
        item_data = format_kpt_item_detail(@kpt_item)

        render json: {
          success: true,
          data: item_data,
          message: "アイテムを完了しました"
        }, status: :ok
      else
        render json: {
          success: false,
          error: "アイテムの完了に失敗しました",
          details: @kpt_item.errors.full_messages
        }, status: :unprocessable_entity
      end
    rescue StandardError => e
      render_error(error: "アイテム完了処理中にエラーが発生しました", status: :internal_server_error)
    end
  end

  # アイテムを再オープン
  def reopen
    begin
      if @kpt_item.update(status: "reopened")
        item_data = format_kpt_item_detail(@kpt_item)

        render json: {
          success: true,
          data: item_data,
          message: "アイテムを再オープンしました"
        }, status: :ok
      else
        render json: {
          success: false,
          error: "アイテムの再オープンに失敗しました",
          details: @kpt_item.errors.full_messages
        }, status: :unprocessable_entity
      end
    rescue StandardError => e
      render_error(error: "アイテム再オープン処理中にエラーが発生しました", status: :internal_server_error)
    end
  end

  # アイテムを移動
  def move
    begin
      new_kpt_session = current_user.kpt_sessions.find(params[:new_kpt_session_id])
      if @kpt_item.update(kpt_session_id: new_kpt_session.id)
        item_data = format_kpt_item_detail(@kpt_item)

        render json: {
          success: true,
          data: item_data,
          message: "アイテムを移動しました"
        }, status: :ok
      else
        render json: {
          success: false,
          error: "アイテムの移動に失敗しました",
          details: @kpt_item.errors.full_messages
        }, status: :unprocessable_entity
      end
    rescue ActiveRecord::RecordNotFound => e
      render json: {
        success: false,
        error: "セッションが見つかりません"
      }, status: :not_found
    rescue StandardError => e
      render_error(error: "アイテムの移動中にエラーが発生しました", status: :internal_server_error)
    end
  end

  # アイテムをコピー
  def copy
    begin
      new_kpt_session = current_user.kpt_sessions.find(params[:new_kpt_session_id])
      @kpt_item = @kpt_item.dup
      @kpt_item.kpt_session_id = new_kpt_session.id

      puts "status: #{@kpt_item.status.inspect} (#{@kpt_item.status.class})"
      puts "type: #{@kpt_item.type.inspect} (#{@kpt_item.type.class})"
      unless @kpt_item.valid?
        puts "Validation errors (valid?): #{@kpt_item.errors.full_messages.inspect}"
      end

      if @kpt_item.save
        item_data = format_kpt_item_detail(@kpt_item)

        render json: {
          success: true,
          data: item_data,
          message: "アイテムをコピーしました"
        }, status: :created
      else
        render json: {
          success: false,
          error: "アイテムのコピーに失敗しました",
          details: @kpt_item.errors.full_messages
        }, status: :unprocessable_entity
      end
    rescue ActiveRecord::RecordNotFound => e
      render json: {
        success: false,
        error: "セッションが見つかりません"
      }, status: :not_found
    rescue StandardError => e
      render_error(error: "アイテムのコピー中にエラーが発生しました", status: :internal_server_error)
    end
  end

  # アイテムに作業ログをリンク
  def link_work_log
    begin
      work_log = current_user.work_logs.find(params[:work_log_id])
      if @kpt_item.work_logs.include?(work_log)
        render json: {
          success: false,
          error: "このアイテムには既にこの作業ログがリンクされています"
        }, status: :unprocessable_entity
        return
      end

      if @kpt_item.work_logs << work_log
        item_data = format_kpt_item_detail(@kpt_item)

        render json: {
          success: true,
          data: item_data,
          message: "アイテムに作業ログをリンクしました"
        }, status: :ok
      else
        render json: {
          success: false,
          error: "アイテムに作業ログのリンクに失敗しました",
          details: @kpt_item.errors.full_messages
        }, status: :unprocessable_entity
      end
    rescue ActiveRecord::RecordNotFound => e
      render json: {
        success: false,
        error: "作業ログが見つかりません"
      }, status: :not_found
    rescue StandardError => e
      render_error(error: "アイテムに作業ログのリンク中にエラーが発生しました", status: :internal_server_error)
    end
  end

  # アイテムから作業ログをアンリンク
  def unlink_work_log
    begin
      work_log = current_user.work_logs.find(params[:work_log_id])
      if @kpt_item.work_logs.include?(work_log)
        if @kpt_item.work_logs.delete(work_log)
          item_data = format_kpt_item_detail(@kpt_item)

          render json: {
            success: true,
            data: item_data,
            message: "アイテムから作業ログをアンリンクしました"
          }, status: :ok
        else
          render json: {
            success: false,
            error: "アイテムから作業ログのアンリンクに失敗しました",
            details: @kpt_item.errors.full_messages
          }, status: :unprocessable_entity
        end
      else
        render json: {
          success: false,
          error: "このアイテムにはこの作業ログがリンクされていません"
        }, status: :unprocessable_entity
      end
    rescue ActiveRecord::RecordNotFound => e
      render json: {
        success: false,
        error: "作業ログが見つかりません"
      }, status: :not_found
    rescue StandardError => e
      render_error(error: "アイテムから作業ログのアンリンク中にエラーが発生しました", status: :internal_server_error)
    end
  end

  # アイテム統計を取得
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
        message: "アイテム統計を取得しました"
      }, status: :ok
    rescue StandardError => e
      render_error(error: "統計データの取得に失敗しました", status: :internal_server_error)
    end
  end

  # アイテム傾向分析を取得
  def trends
    begin
      days = params[:days]&.to_i || 30
      days = [ days, 365 ].min # 最大1年
      days = 7 if days < 7    # 最小1週間

      trends_data = {
        emotion_trend: KptItem.emotion_trend(current_user, days),
        impact_distribution: KptItem.impact_distribution(current_user),
        completion_trend: calculate_completion_trend(days)
      }

      render json: {
        success: true,
        data: trends_data,
        period_days: days,
        message: "#{days}日間の傾向分析を取得しました"
      }, status: :ok
    rescue StandardError => e
      render_error(error: "傾向分析の取得に失敗しました", status: :internal_server_error)
    end
  end

  # GitHub Issuesのインポート
  # @description 選択されたGitHub IssuesをKPTアイテムとして一括保存
  # @return [JSON] 保存結果（success, error）
  def import_github
    begin
      puts "=== import_github started ==="
      items_params = import_github_params
      puts "items_params: #{items_params.inspect}"

      kpt_session = current_user.kpt_sessions.last
      unless kpt_session
        puts "Creating new KPT session"
        kpt_session = current_user.kpt_sessions.create!(
          session_date: Date.current,
          title: "GitHub Issues Import - #{Time.current.strftime('%Y-%m-%d %H:%M')}"
        )
      end
      puts "Using KPT session: #{kpt_session.inspect}"

      success_count = 0
      error_count = 0
      error_messages = []

      items_params.each_with_index do |item_params, idx|
        # GitHubのstateをKPTのstatusに変換
        status = case item_params[:status].to_s.downcase
        when "open"
          "open"
        when "in_progress", "doing"
          "in_progress"
        when "completed", "done", "closed"
          "completed"
        when "cancelled", "rejected"
          "cancelled"
        else
          puts "Unknown status: #{item_params[:status]}, defaulting to 'open'"
          "open"
        end
        puts "[#{idx}] Converted status: #{status}"

        kpt_item = KptItem.new(
          kpt_session_id: kpt_session.id,
          type: item_params[:type],
          content: item_params[:content],
          status: status,
          priority: item_params[:priority],
          notes: item_params[:notes],
          external_repo: item_params[:external_repo],
          external_number: item_params[:external_number],
          external_url: item_params[:external_url]
        )
        puts "[#{idx}] Created KPT item: #{kpt_item.inspect}"
        puts "[#{idx}] kpt_item.status: '#{kpt_item.status}' (#{kpt_item.status.class})"
        puts "[#{idx}] Allowed STATUSES: #{KptItem::STATUSES.inspect}"

        if kpt_item.valid?
          kpt_item.save!
          puts "[#{idx}] KPT item saved successfully"
          success_count += 1
        else
          puts "[#{idx}] Validation errors: #{kpt_item.errors.full_messages}"
          error_count += 1
          error_messages << "[#{idx}] #{kpt_item.errors.full_messages.join(', ')}"
        end
      end

      if error_count == 0
        render json: {
          success: true,
          message: "GitHub Issuesをインポートしました (#{success_count}件)"
        }, status: :ok
      else
        render json: {
          success: false,
          message: "一部のGitHub Issueのインポートに失敗しました",
          imported_count: success_count,
          failed_count: error_count,
          errors: error_messages
        }, status: :unprocessable_entity
      end
    rescue StandardError => e
      puts "Error in import_github: #{e.class} - #{e.message}"
      puts e.backtrace.join("\n")
      render json: {
        success: false,
        error: "GitHub Issueのインポート中にエラーが発生しました: #{e.message}"
      }, status: :internal_server_error
    end
  end

  # アイテムサマリーを整形
  def format_kpt_item_summary(item)
    {
      id: item.id,
      type: item.type,
      content: item.content.truncate(100),
      priority: item.priority,
      status: item.status,
      due_date: item.due_date,
      start_date: item.start_date,
      end_date: item.end_date,
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

  # 完了傾向を計算
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

  def render_error(error:, status:)
    render json: {
      success: false,
      error: error
    }, status: status
  end

  private

  # KPTアイテムをIDで検索
  def set_kpt_item
    @kpt_item = current_user.kpt_items.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { success: false, error: "指定されたIDのKPTアイテムが見つかりません" }, status: :not_found
  end

  # アイテムのstrong parameter
  def kpt_item_params
    params.require(:kpt_item).permit(
      :type,
      :status,
      :content,
      :priority,
      :notes
    )
  end

  # GitHubインポートのstrong parameter
  def import_github_params
    puts "=== import_github_params called ==="
    items = params.require(:items)
    puts "items.class: #{items.class}"
    items.each_with_index do |item, idx|
      puts "item[#{idx}].class: #{item.class}, item: #{item.inspect}"
    end
    items.map do |item|
      permitted = if item.is_a?(ActionController::Parameters)
        item.permit(:type, :content, :status, :priority, :notes, :external_repo, :external_number, :external_url).to_h
      else
        # すでにHashならそのまま
        item.slice("type", "content", "status", "priority", "notes", "external_repo", "external_number", "external_url")
      end
      puts "permitted: #{permitted.inspect}"
      permitted
    end
  end
end
