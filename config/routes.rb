Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      # 認証
      post "oauth/:provider", to: "oauths#oauth", as: :auth_at_provider
      # get "oauth/callback/:provider", to: "oauths#callback", as: :callback_api_v1_oauths この記述ではエラーになる。
      # /api/v1/oauth/callback?provider=google&code=... のようなpathパラメータではなく、クエリパラのため

      get "oauth/callback", to: "oauths#callback", as: :callback_api_v1_oauths
      get "oauth/:provider", to: "oauths#oauth", as: :oauth_api_v1_oauths
      resource :sessions, only: [:create]
    end
  end
end