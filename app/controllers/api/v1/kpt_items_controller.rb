# frozen_string_literal: true

# KPTアイテムAPIコントローラー
class Api::V1::KptItemsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_kpt_item, only: [ :show, :update, :destroy, :complete, :reopen, :move, :copy, :link_work_log, :unlink_work_log ]

  # KPTアイテム一覧を取得
  def index
    safe_execute do
      type_filter = params[:type]
      status_filter = params[:status]
      
      items = current_user.kpt_items.includes(:kpt_session)
      items = items.where(type: type_filter) if type_filter.present?
      items = items.where(status: status_filter) if status_filter.present?
      
      items_data = items.map { |item| format_kpt_item_summary(item) }
      
      render_success(
        data: { items: items_data },
        message: "アイテム一覧を取得しました"
      )
    end
  end

  # アイテム詳細を取得
  def show
    safe_execute do
      item_data = format_kpt_item_detail(@kpt_item)
      
      render_success(
        data: item_data,
        message: "アイテム詳細を取得しました"
      )
    end
  end

  # アイテムを作成
  def create
    safe_database_operation do
      kpt_session = current_user.kpt_sessions.find(params[:kpt_session_id])
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

      if @kpt_item.save
        item_data = format_kpt_item_detail(@kpt_item)

        render_success(
          data: item_data,
          message: "アイテムを作成しました",
          status: :created
        )
      else
        render_validation_error(@kpt_item, "アイテムの作成に失敗しました")
      end
    end
  end

  # アイテムを更新
  def update
    safe_database_operation do
      if @kpt_item.update(kpt_item_params)
        render_success(message: "アイテムを更新しました")
      else
        render_validation_error(@kpt_item, "アイテムの更新に失敗しました")
      end
    end
  end

  # アイテムを削除
  def destroy
    safe_database_operation do
      if @kpt_item.destroy
        render_success(message: "アイテムを削除しました")
      else
        render_validation_error(@kpt_item, "アイテムの削除に失敗しました")
      end
    end
  end

  # アイテムを完了
  def complete
    safe_database_operation do
      if @kpt_item.update(status: "completed")
        item_data = format_kpt_item_detail(@kpt_item)

        render_success(
          data: item_data,
          message: "アイテムを完了しました"
        )
      else
        render_validation_error(@kpt_item, "アイテムの完了に失敗しました")
      end
    end
  end

  # アイテムを再オープン
  def reopen
    safe_database_operation do
      if @kpt_item.update(status: "reopened")
        item_data = format_kpt_item_detail(@kpt_item)

        render_success(
          data: item_data,
          message: "アイテムを再オープンしました"
        )
      else
        render_validation_error(@kpt_item, "アイテムの再オープンに失敗しました")
      end
    end
  end

  # アイテムを移動
  def move
    safe_database_operation do
      new_kpt_session = current_user.kpt_sessions.find(params[:new_kpt_session_id])
      if @kpt_item.update(kpt_session_id: new_kpt_session.id)
        item_data = format_kpt_item_detail(@kpt_item)

        render_success(
          data: item_data,
          message: "アイテムを移動しました"
        )
      else
        render_validation_error(@kpt_item, "アイテムの移動に失敗しました")
      end
    end
  end

  # アイテムをコピー
  def copy
    safe_database_operation do
      new_kpt_session = current_user.kpt_sessions.find(params[:new_kpt_session_id])
      @kpt_item = @kpt_item.dup
      @kpt_item.kpt_session_id = new_kpt_session.id

      if @kpt_item.save
        item_data = format_kpt_item_detail(@kpt_item)

        render_success(
          data: item_data,
          message: "アイテムをコピーしました",
          status: :created
        )
      else
        render_validation_error(@kpt_item, "アイテムのコピーに失敗しました")
      end
    end
  end

  # アイテムに作業ログをリンク
  def link_work_log
    safe_database_operation do
      work_log = current_user.work_logs.find(params[:work_log_id])
      if @kpt_item.work_logs.include?(work_log)
        render_error(
          error: "このアイテムには既にこの作業ログがリンクされています",
          status: :unprocessable_entity
        )
        return
      end

      @kpt_item.work_logs << work_log
      render_success(message: "作業ログをリンクしました")
    end
  end

  # アイテムから作業ログをリンク解除
  def unlink_work_log
    safe_database_operation do
      work_log = current_user.work_logs.find(params[:work_log_id])
      if @kpt_item.work_logs.delete(work_log)
        render_success(message: "作業ログのリンクを解除しました")
      else
        render_error(
          error: "作業ログのリンク解除に失敗しました",
          status: :unprocessable_entity
        )
      end
    end
  end

  # 統計情報を取得
  def stats
    safe_execute do
      days = params[:days]&.to_i || 30
      start_date = days.days.ago.to_date
      
      items = current_user.kpt_items.joins(:kpt_session)
                          .where(kpt_sessions: { session_date: start_date..Date.current })

      stats_data = {
        total_items: items.count,
        completed_items: items.completed.count,
        completion_rate: items.count > 0 ? (items.completed.count.to_f / items.count * 100).round(2) : 0,
        by_type: items.group(:type).count,
        by_status: items.group(:status).count,
        by_priority: items.group(:priority).count
      }

      render_success(
        data: stats_data,
        message: "#{days}日間の統計情報を取得しました"
      )
    end
  end

  # 傾向分析を取得
  def trends
    safe_execute do
      days = params[:days]&.to_i || 30
      trend_data = calculate_completion_trend(days)

      render_success(
        data: trend_data,
        message: "#{days}日間の傾向分析を取得しました"
      )
    end
  end

  # GitHub Issuesのインポート
  # @description 選択されたGitHub IssuesをKPTアイテムとして一括保存
  # @return [JSON] 保存結果（success, error）
  def import_github
    safe_database_operation do
      items_params = import_github_params

      kpt_session = current_user.kpt_sessions.last
      unless kpt_session
        kpt_session = current_user.kpt_sessions.create!(
          session_date: Date.current,
          title: "GitHub Issues Import - #{Time.current.strftime('%Y-%m-%d %H:%M')}"
        )
      end

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
          "open"
        end

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

        if kpt_item.valid?
          kpt_item.save!
          success_count += 1
        else
          error_count += 1
          error_messages << "[#{idx}] #{kpt_item.errors.full_messages.join(', ')}"
        end
      end

      if error_count == 0
        render_success(
          message: "GitHub Issuesをインポートしました (#{success_count}件)"
        )
      else
        render_error(
          error: "一部のGitHub Issueのインポートに失敗しました",
          status: :unprocessable_entity,
          details: {
            imported_count: success_count,
            failed_count: error_count,
            errors: error_messages
          }
        )
      end
    end
  end

  private

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

  # KPTアイテムをIDで検索
  def set_kpt_item
    @kpt_item = current_user.kpt_items.find(params[:id])
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
    items = params.require(:items)
    items.map do |item|
      if item.is_a?(ActionController::Parameters)
        item.permit(:type, :content, :status, :priority, :notes, :external_repo, :external_number, :external_url).to_h
      else
        # すでにHashならそのまま
        item.slice("type", "content", "status", "priority", "notes", "external_repo", "external_number", "external_url")
      end
    end
  end
end
