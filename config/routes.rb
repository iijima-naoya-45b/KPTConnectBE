Rails.application.routes.draw do
  namespace :modules do
    namespace :v1 do
      # 認証
      get "oauth/callback", to: "oauths#callback"
      post "oauth/:provider", to: "oauths#oauth", as: :auth_at_provider
    end
  end
end
