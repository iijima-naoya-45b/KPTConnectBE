# Be sure to restart your server when you modify this file.

# Avoid CORS issues when API is called from the frontend app.
# Handle Cross-Origin Resource Sharing (CORS) in order to accept cross-origin Ajax requests.

# Read more: https://github.com/cyu/rack-cors

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    # フロントエンドのオリジンを指定
    origins "http://localhost:3000", "https://www.kpt-connect.biz/"
    # origins "https://your-production-domain.com"  # 本番環境用

    resource "*",
      headers: :any,
      expose: [ "Authorization" ],
      methods: [ :get, :post, :put, :patch, :delete, :options, :head ],
      credentials: true  # クッキーや認証情報の送信を許可
  end
end
