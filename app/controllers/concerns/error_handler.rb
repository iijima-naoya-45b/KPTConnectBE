# frozen_string_literal: true

module ErrorHandler
  extend ActiveSupport::Concern

  included do
    rescue_from StandardError, with: :handle_standard_error
    rescue_from ActiveRecord::RecordNotFound, with: :handle_record_not_found
    rescue_from ActiveRecord::RecordInvalid, with: :handle_record_invalid
    rescue_from ActionController::ParameterMissing, with: :handle_parameter_missing
    rescue_from ActionController::UnpermittedParameters, with: :handle_unpermitted_parameters
    rescue_from JSON::ParserError, with: :handle_json_parser_error
  end

  private

  # 標準エラーの処理
  def handle_standard_error(exception)
    render_error(
      error: "サーバー内部エラーが発生しました",
      status: :internal_server_error
    )
  end

  # レコードが見つからないエラーの処理
  def handle_record_not_found(exception)
    render_not_found("指定されたリソースが見つかりません")
  end

  # レコードのバリデーションエラーの処理
  def handle_record_invalid(exception)
    render_validation_error(exception.record)
  end

  # パラメータ不足エラーの処理
  def handle_parameter_missing(exception)
    render_error(
      error: "必要なパラメータが不足しています: #{exception.param}",
      status: :bad_request
    )
  end

  # 許可されていないパラメータエラーの処理
  def handle_unpermitted_parameters(exception)
    render_error(
      error: "許可されていないパラメータが含まれています: #{exception.params.join(', ')}",
      status: :bad_request
    )
  end

  # JSONパースエラーの処理
  def handle_json_parser_error(exception)
    render_error(
      error: "JSONの形式が正しくありません",
      status: :bad_request
    )
  end

  # セーフなブロック実行
  def safe_execute
    yield
  rescue StandardError => e
    handle_standard_error(e)
  end

  # データベース操作のセーフ実行
  def safe_database_operation
    ActiveRecord::Base.transaction do
      yield
    end
  rescue ActiveRecord::RecordInvalid => e
    handle_record_invalid(e)
  rescue ActiveRecord::RecordNotFound => e
    handle_record_not_found(e)
  rescue StandardError => e
    handle_standard_error(e)
  end
end
