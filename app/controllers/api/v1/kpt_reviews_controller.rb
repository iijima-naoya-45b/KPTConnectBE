module Api
  module V1
    class KptReviewsController < ApplicationController
      before_action :authenticate_user!
      # protect_from_forgery with: :null_session

      def create
        kpt_review = KptReview.new(kpt_review_params.merge(user_id: current_user.id))
        if kpt_review.save
          render json: { message: 'KPT振り返りを保存しました', kpt_review: kpt_review }, status: :created
        else
          render json: { message: '保存に失敗しました', errors: kpt_review.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def index
        begin
          reviews = KptReview.where(user_id: current_user.id)
          if params[:start].present? && params[:end].present?
            start_date = Date.parse(params[:start]) rescue nil
            end_date = Date.parse(params[:end]) rescue nil
            if start_date && end_date
              reviews = reviews.where(created_at: start_date.beginning_of_day..end_date.end_of_day)
            else
              return render json: { message: '日付パラメータが不正です', params: params }, status: :bad_request
            end
          end
          render json: reviews.order(created_at: :desc)
        rescue => e
          render json: { message: 'KPTレビュー一覧取得時にエラー', error: e.message, params: params }, status: :internal_server_error
        end
      end

      def update
        begin
          kpt_review = KptReview.find_by(id: params[:id], user_id: current_user.id)
          if kpt_review.nil?
            return render json: { message: 'KPTレビューが見つかりません', id: params[:id] }, status: :not_found
          end
          if kpt_review.update(kpt_review_params)
            render json: { message: 'KPTレビューを更新しました', kpt_review: kpt_review }, status: :ok
          else
            render json: { message: '更新に失敗しました', errors: kpt_review.errors.full_messages }, status: :unprocessable_entity
          end
        rescue => e
          render json: { message: 'KPTレビュー更新時にエラー', error: e.message, params: params }, status: :internal_server_error
        end
      end

      def destroy
        begin
          kpt_review = KptReview.find_by(id: params[:id], user_id: current_user.id)
          if kpt_review.nil?
            return render json: { message: 'KPTレビューが見つかりません', id: params[:id] }, status: :not_found
          end
          kpt_review.destroy
          render json: { message: 'KPTレビューを削除しました', id: kpt_review.id }, status: :ok
        rescue => e
          render json: { message: 'KPTレビュー削除時にエラー', error: e.message, params: params }, status: :internal_server_error
        end
      end

      private

      def kpt_review_params
        params.require(:kpt_review).permit(:title, :description, :keep, :problem, :try)
      end
    end
  end
end
