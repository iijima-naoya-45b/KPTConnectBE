require_relative "boot"

require "rails/all"

Bundler.require(*Rails.groups)

module KptBe
  class Application < Rails::Application
    config.load_defaults 8.0

    config.middleware.use ActionDispatch::Cookies
    config.middleware.use ActionDispatch::Session::CookieStore


    config.autoload_lib(ignore: %w[assets tasks])

    config.api_only = true
  end
end
