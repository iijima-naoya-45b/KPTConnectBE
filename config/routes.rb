Rails.application.routes.draw do
  root to: proc { [ 200, { "Content-Type" => "text/plain" }, [ "OK" ] ] }
  namespace :api do
    namespace :v1 do
      resources :todos, only: [:create, :index, :show, :update] do
        collection do
          post :suggest
        end
      end
      # 認証
      post "oauth/:provider", to: "oauths#oauth", as: :auth_at_provider
      get "oauth/:provider/callback", to: "oauths#callback", as: :auth_callback
      # get "oauth/callback/:provider", to: "oauths#callback", as: :callback_api_v1_oauths この記述ではエラーになる。
      # /api/v1/oauth/callback?provider=google&code=... のようなpathパラメータではなく、クエリパラのため

      get "oauth/callback", to: "oauths#callback", as: :callback_api_v1_oauths
      get "oauth/:provider", to: "oauths#oauth", as: :oauth_api_v1_oauths

      # セッション管理
      resource :sessions, only: [ :create ] do
        delete :logout, on: :collection
      end

      # ユーザー管理
      get "me", to: "users#me"
      put "me", to: "users#update"
      resources :users, only: [] do
        collection do
          get :settings
          put :settings, to: "users#update_settings"
          get :stats
          delete :account, to: "users#destroy_account"
          post :avatar, to: "users#upload_avatar"
        end
      end

      # ダッシュボード機能
      resources :dashboard, only: [ :index ] do
        collection do
          get :summary
          get :stats
          get :activity
          get :overview
          get :trends
        end
      end

      # KPTセッション管理
      resources :kpt_sessions do
        member do
          post :complete
          post :save_template
        end
        collection do
          get :stats
        end
      end

      # KPTアイテム管理
      resources :kpt_items, except: [ :new, :edit ] do
        member do
          post :complete
          put :update_status
        end
        collection do
          get :stats
          get :trends
          post :import_github
        end
      end

      # 作業ログ管理
      resources :work_logs do
        member do
          post :complete
          post :link_kpt
          delete "link_kpt/:kpt_session_id", to: "work_logs#unlink_kpt", as: :unlink_kpt
        end
        collection do
          get :stats
          get :productivity
        end
      end

      # チャート管理
      resources :charts do
        member do
          get :data
          post :favorite
        end
        collection do
          put :reorder
        end
      end

      # サブスクリプション管理
      resources :subscriptions do
        member do
          post :resume
        end
        collection do
          get :plans
          get :payments
        end
      end

      # 通知管理
      resources :notifications, except: [ :new, :edit, :create, :update ] do
        member do
          put :read
        end
        collection do
          put :mark_all_read
          get :settings
          put :settings, to: "notifications#update_settings"
          post :test
          get :stats
        end
      end

      # インサイト・分析機能
      resources :insights, except: [ :new, :edit ] do
        collection do
          post :generate
          get :patterns
          get :recommendations
        end
      end

      # 個人振り返りカレンダー機能
      namespace :calendar do
        get :reflection_calendar, to: "reflections#index"
        get :monthly_data, to: "reflections#monthly_data"
        get :growth_timeline, to: "reflections#growth_timeline"
        get :growth_analytics, to: "reflections#growth_analytics"
        get :personal_stats, to: "reflections#personal_stats"
        post :mark_reflection, to: "reflections#mark_reflection"
        delete :unmark_reflection, to: "reflections#unmark_reflection"
      end

      # フィードバック管理
      resources :feedbacks, except: [ :new, :edit ] do
        collection do
          get :dashboard
          get :export
        end
      end

      get "github/repositories", to: "github#repositories"
      get "github/index", to: "github#index"
      get "github/issues", to: "github#issues"
      get "github/pull_requests", to: "github#pull_requests"
      post "github/save_issues", to: "github#save_issues"
      delete "github/issues/:id", to: "github#destroy"

      resources :goals do
        collection do
          post :suggest
        end
        member do
          patch "action_plans/:action_id", to: "goals#update_action_plan_progress", as: "update_action_plan"
        end
      end

      # お問い合わせ
      resources :contacts, only: [ :create ]

      # Slack integration
      post "slack/commands", to: "slack#commands"
      post "slack/interactive", to: "slack#interactive"

      post "create-payment-intent", to: "payments#create_payment_intent"
      post "create-subscription", to: "payments#create_subscription"

      resources :todos, only: [] do
        collection do
          post :suggest
        end
      end
    end
  end
  post "/webhook", to: "webhook#receive"
end
