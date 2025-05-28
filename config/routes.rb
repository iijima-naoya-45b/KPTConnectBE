Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      get 'debug/jwt', to: 'users#debug_jwt'
      get 'debug/cookies', to: 'users#debug_cookies'
      # 認証
      post "oauth/:provider", to: "oauths#oauth", as: :auth_at_provider
      # get "oauth/callback/:provider", to: "oauths#callback", as: :callback_api_v1_oauths この記述ではエラーになる。
      # /api/v1/oauth/callback?provider=google&code=... のようなpathパラメータではなく、クエリパラのため

      get "oauth/callback", to: "oauths#callback", as: :callback_api_v1_oauths
      get "oauth/:provider", to: "oauths#oauth", as: :oauth_api_v1_oauths
      
      # セッション管理
      resource :sessions, only: [:create] do
        delete :logout, on: :collection
      end
      
      # ユーザー情報取得
      get "me", to: "users#me"
    end
  end
end