class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError

  # ログ設定
  around_perform do |job, block|
    Rails.logger.info "Job開始: #{job.class.name} - Job ID: #{job.job_id}"
    begin
      block.call
      Rails.logger.info "Job完了: #{job.class.name} - Job ID: #{job.job_id}"
    rescue => e
      Rails.logger.error "Jobエラー: #{job.class.name} - Job ID: #{job.job_id}, Error: #{e.message}"
      raise
    end
  end
end
