require_relative "boot"

require "rails/all"

Bundler.require(*Rails.groups)

module KptBe
  class Application < Rails::Application
    config.load_defaults 8.0

    config.middleware.use ActionDispatch::Cookies
    config.middleware.use ActionDispatch::Session::CookieStore

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    config.time_zone = "Tokyo"
    config.active_record.default_timezone = :local

    config.autoload_lib(ignore: %w[assets tasks])

    config.api_only = true

    # Active Job設定
    config.active_job.queue_adapter = :async

    # 開発環境でのログ設定
    if Rails.env.development?
      config.log_level = :debug
      config.active_job.logger = Rails.logger
    end
  end
end
