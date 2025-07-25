# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_07_13_105853) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "authentications", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "provider"
    t.string "uid"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_authentications_on_user_id"
  end

  create_table "charts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "name", limit: 200, null: false
    t.text "description"
    t.string "chart_type", limit: 50, null: false
    t.jsonb "config", null: false
    t.jsonb "data_query", null: false
    t.boolean "is_public", default: false
    t.boolean "is_favorite", default: false
    t.integer "display_order", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["chart_type"], name: "index_charts_on_chart_type"
    t.index ["created_at"], name: "index_charts_on_created_at"
    t.index ["display_order"], name: "index_charts_on_display_order"
    t.index ["is_favorite"], name: "index_charts_on_is_favorite"
    t.index ["is_public"], name: "index_charts_on_is_public"
    t.index ["user_id", "chart_type"], name: "index_charts_on_user_id_and_chart_type"
    t.index ["user_id", "display_order"], name: "index_charts_on_user_id_and_display_order"
    t.index ["user_id", "is_favorite"], name: "index_charts_on_user_id_and_is_favorite"
    t.index ["user_id"], name: "index_charts_on_user_id"
    t.check_constraint "chart_type::text = ANY (ARRAY['line'::character varying, 'bar'::character varying, 'pie'::character varying, 'area'::character varying, 'scatter'::character varying, 'heatmap'::character varying, 'treemap'::character varying]::text[])", name: "check_charts_type"
  end

  create_table "feedback_priorities", force: :cascade do |t|
    t.string "name", limit: 100, null: false, comment: "フィードバック優先度名"
    t.string "key", limit: 50, null: false, comment: "フィードバック優先度キー（システム内部用）"
    t.text "description", comment: "フィードバック優先度説明"
    t.integer "display_order", default: 0, null: false, comment: "表示順序"
    t.integer "priority_level", default: 1, null: false, comment: "優先度レベル（数値が大きいほど高優先度）"
    t.boolean "is_active", default: true, null: false, comment: "アクティブ状態"
    t.string "color_code", limit: 7, comment: "表示用カラーコード（#FFFFFF形式）"
    t.string "badge_class", limit: 100, comment: "CSSバッジクラス名"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["is_active", "display_order"], name: "index_feedback_priorities_on_active_and_order"
    t.index ["key"], name: "index_feedback_priorities_on_key", unique: true
    t.index ["priority_level"], name: "index_feedback_priorities_on_level"
  end

  create_table "feedback_types", force: :cascade do |t|
    t.string "name", limit: 100, null: false, comment: "フィードバック種別名"
    t.string "key", limit: 50, null: false, comment: "フィードバック種別キー（システム内部用）"
    t.text "description", comment: "フィードバック種別説明"
    t.integer "display_order", default: 0, null: false, comment: "表示順序"
    t.boolean "is_active", default: true, null: false, comment: "アクティブ状態"
    t.string "color_code", limit: 7, comment: "表示用カラーコード（#FFFFFF形式）"
    t.string "icon_name", limit: 50, comment: "アイコン名"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "type"
    t.index ["is_active", "display_order"], name: "index_feedback_types_on_active_and_order"
    t.index ["key"], name: "index_feedback_types_on_key", unique: true
  end

  create_table "feedbacks", force: :cascade do |t|
    t.bigint "user_id", null: false, comment: "ユーザーID"
    t.bigint "feedback_type_id", null: false, comment: "フィードバック種別ID"
    t.bigint "feedback_priority_id", null: false, comment: "フィードバック優先度ID"
    t.string "title", limit: 255, null: false, comment: "フィードバックタイトル"
    t.text "description", null: false, comment: "フィードバック詳細説明"
    t.string "email", limit: 255, null: false, comment: "フィードバック送信者メールアドレス"
    t.string "status", limit: 50, default: "unread", null: false, comment: "ステータス（unread/in_progress/resolved）"
    t.text "admin_notes", comment: "管理者メモ"
    t.datetime "resolved_at", comment: "解決日時"
    t.json "metadata", comment: "追加データ（ブラウザ情報、OS情報等）"
    t.boolean "is_active", default: true, null: false, comment: "アクティブ状態"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "type"
    t.integer "feedbackCategory"
    t.index ["feedback_priority_id"], name: "index_feedbacks_on_feedback_priority_id"
    t.index ["feedback_priority_id"], name: "index_feedbacks_on_priority"
    t.index ["feedback_type_id"], name: "index_feedbacks_on_feedback_type_id"
    t.index ["feedback_type_id"], name: "index_feedbacks_on_type"
    t.index ["status", "created_at"], name: "index_feedbacks_on_status_and_created"
    t.index ["user_id", "created_at"], name: "index_feedbacks_on_user_and_created"
    t.index ["user_id"], name: "index_feedbacks_on_user_id"
  end

  create_table "github_issues", force: :cascade do |t|
    t.integer "number"
    t.string "title"
    t.text "body"
    t.string "state"
    t.datetime "closed_at"
    t.string "user_login"
    t.text "labels", default: [], array: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
  end

  create_table "goals", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "title", null: false
    t.integer "progress", default: 0, null: false
    t.text "description"
    t.date "deadline"
    t.json "action_plan", default: []
    t.string "status", default: "not_started", null: false
    t.text "progress_check"
    t.boolean "created_by_ai", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_goals_on_user_id"
  end

  create_table "insights", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "kpt_session_id", null: false
    t.integer "user_id", null: false
    t.string "insight_type", limit: 50, null: false
    t.string "title", limit: 200, null: false
    t.jsonb "content", null: false
    t.decimal "confidence_score", precision: 3, scale: 2
    t.string "data_source", limit: 50, default: "ai_analysis"
    t.jsonb "metadata"
    t.boolean "is_active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["confidence_score"], name: "index_insights_on_confidence_score"
    t.index ["content"], name: "index_insights_on_content", using: :gin
    t.index ["created_at"], name: "index_insights_on_created_at"
    t.index ["data_source"], name: "index_insights_on_data_source"
    t.index ["insight_type"], name: "index_insights_on_insight_type"
    t.index ["is_active"], name: "index_insights_on_is_active"
    t.index ["kpt_session_id", "insight_type"], name: "index_insights_on_kpt_session_id_and_insight_type"
    t.index ["kpt_session_id"], name: "index_insights_on_kpt_session_id"
    t.index ["user_id", "insight_type"], name: "index_insights_on_user_id_and_insight_type"
    t.index ["user_id"], name: "index_insights_on_user_id"
    t.check_constraint "confidence_score >= 0::numeric AND confidence_score <= 1::numeric", name: "check_insights_confidence_score"
    t.check_constraint "insight_type::text = ANY (ARRAY['summary'::character varying, 'sentiment'::character varying, 'trend'::character varying, 'recommendation'::character varying, 'pattern'::character varying]::text[])", name: "check_insights_type"
  end

  create_table "kpt_items", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "kpt_session_id", null: false
    t.string "type", limit: 10, null: false
    t.text "content", null: false
    t.date "due_date"
    t.string "assigned_to", limit: 100
    t.integer "emotion_score"
    t.integer "impact_score"
    t.text "tags", default: [], array: true
    t.text "notes"
    t.datetime "completed_at", precision: nil
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.date "start_date"
    t.date "end_date"
    t.index ["completed_at"], name: "index_kpt_items_on_completed_at"
    t.index ["due_date"], name: "index_kpt_items_on_due_date"
    t.index ["emotion_score"], name: "index_kpt_items_on_emotion_score"
    t.index ["impact_score"], name: "index_kpt_items_on_impact_score"
    t.index ["kpt_session_id"], name: "index_kpt_items_on_kpt_session_id"
    t.index ["tags"], name: "index_kpt_items_on_tags", using: :gin
    t.index ["type"], name: "index_kpt_items_on_type"
    t.check_constraint "emotion_score >= 1 AND emotion_score <= 5", name: "check_kpt_items_emotion_score"
    t.check_constraint "impact_score >= 1 AND impact_score <= 5", name: "check_kpt_items_impact_score"
    t.check_constraint "type::text = ANY (ARRAY['keep'::character varying, 'problem'::character varying, 'try'::character varying]::text[])", name: "check_kpt_items_type"
  end

  create_table "kpt_reviews", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "title"
    t.string "description"
    t.text "keep"
    t.text "problem"
    t.text "try"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_kpt_reviews_on_user_id"
  end

  create_table "kpt_sessions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "title", limit: 200, null: false
    t.text "description"
    t.date "session_date", default: -> { "CURRENT_DATE" }, null: false
    t.text "tags", default: [], array: true
    t.boolean "is_template", default: false
    t.string "template_name", limit: 100
    t.datetime "completed_at", precision: nil
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["completed_at"], name: "index_kpt_sessions_on_completed_at"
    t.index ["is_template"], name: "index_kpt_sessions_on_is_template"
    t.index ["session_date"], name: "index_kpt_sessions_on_session_date"
    t.index ["tags"], name: "index_kpt_sessions_on_tags", using: :gin
    t.index ["user_id"], name: "index_kpt_sessions_on_user_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "title"
    t.text "message"
    t.string "notification_type"
    t.boolean "is_read"
    t.datetime "read_at"
    t.string "priority"
    t.string "action_url"
    t.jsonb "metadata"
    t.datetime "expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "payment_methods", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "stripe_payment_method_id", limit: 255, null: false
    t.string "type", limit: 50, null: false
    t.string "last4", limit: 4
    t.string "brand", limit: 50
    t.integer "exp_month"
    t.integer "exp_year"
    t.boolean "is_default", default: false
    t.boolean "is_active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["brand"], name: "index_payment_methods_on_brand"
    t.index ["is_active"], name: "index_payment_methods_on_is_active"
    t.index ["is_default"], name: "index_payment_methods_on_is_default"
    t.index ["stripe_payment_method_id"], name: "index_payment_methods_on_stripe_payment_method_id", unique: true
    t.index ["type"], name: "index_payment_methods_on_type"
    t.index ["user_id", "is_active"], name: "index_payment_methods_on_user_id_and_is_active"
    t.index ["user_id", "is_default"], name: "index_payment_methods_on_user_id_and_is_default"
    t.index ["user_id", "type"], name: "index_payment_methods_on_user_id_and_type"
    t.index ["user_id"], name: "index_payment_methods_on_user_id"
    t.check_constraint "exp_month >= 1 AND exp_month <= 12", name: "check_payment_methods_exp_month"
    t.check_constraint "type::text = ANY (ARRAY['card'::character varying, 'bank_account'::character varying, 'sepa_debit'::character varying]::text[])", name: "check_payment_methods_type"
  end

  create_table "payments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "user_id", null: false
    t.uuid "subscription_id"
    t.string "stripe_payment_intent_id", limit: 255, null: false
    t.integer "amount", null: false
    t.string "currency", limit: 3, default: "jpy", null: false
    t.string "status", limit: 50, null: false
    t.string "payment_method_type", limit: 50
    t.text "description"
    t.text "receipt_url"
    t.string "invoice_id", limit: 255
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["amount"], name: "index_payments_on_amount"
    t.index ["created_at"], name: "index_payments_on_created_at"
    t.index ["currency"], name: "index_payments_on_currency"
    t.index ["payment_method_type"], name: "index_payments_on_payment_method_type"
    t.index ["status", "created_at"], name: "index_payments_on_status_and_created_at"
    t.index ["status"], name: "index_payments_on_status"
    t.index ["stripe_payment_intent_id"], name: "index_payments_on_stripe_payment_intent_id", unique: true
    t.index ["subscription_id", "created_at"], name: "index_payments_on_subscription_id_and_created_at"
    t.index ["subscription_id"], name: "index_payments_on_subscription_id"
    t.index ["user_id", "created_at"], name: "index_payments_on_user_id_and_created_at"
    t.index ["user_id", "status"], name: "index_payments_on_user_id_and_status"
    t.index ["user_id"], name: "index_payments_on_user_id"
    t.check_constraint "status::text = ANY (ARRAY['succeeded'::character varying, 'pending'::character varying, 'failed'::character varying, 'canceled'::character varying, 'requires_action'::character varying]::text[])", name: "check_payments_status"
  end

  create_table "reflection_marks", force: :cascade do |t|
    t.bigint "user_id", null: false, comment: "ユーザーID"
    t.date "date", null: false, comment: "マークした日付"
    t.string "note", limit: 500, comment: "メモ"
    t.string "mark_type", default: "reflection", null: false, comment: "マークタイプ"
    t.json "metadata", comment: "追加データ（JSON）"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_reflection_marks_on_created_at"
    t.index ["date"], name: "index_reflection_marks_on_date"
    t.index ["mark_type"], name: "index_reflection_marks_on_mark_type"
    t.index ["user_id", "date"], name: "index_reflection_marks_on_user_and_date", unique: true
    t.index ["user_id"], name: "index_reflection_marks_on_user_id"
  end

  create_table "subscriptions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "stripe_subscription_id", limit: 255, null: false
    t.string "stripe_price_id", limit: 255, null: false
    t.string "status", limit: 50, null: false
    t.datetime "current_period_start", precision: nil, null: false
    t.datetime "current_period_end", precision: nil, null: false
    t.datetime "trial_start", precision: nil
    t.datetime "trial_end", precision: nil
    t.datetime "canceled_at", precision: nil
    t.boolean "cancel_at_period_end", default: false
    t.string "plan_name", limit: 100
    t.string "billing_cycle", limit: 20
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["billing_cycle"], name: "index_subscriptions_on_billing_cycle"
    t.index ["current_period_end"], name: "index_subscriptions_on_current_period_end"
    t.index ["plan_name"], name: "index_subscriptions_on_plan_name"
    t.index ["status", "current_period_end"], name: "index_subscriptions_on_status_and_current_period_end"
    t.index ["status"], name: "index_subscriptions_on_status"
    t.index ["stripe_price_id"], name: "index_subscriptions_on_stripe_price_id"
    t.index ["stripe_subscription_id"], name: "index_subscriptions_on_stripe_subscription_id", unique: true
    t.index ["user_id", "status"], name: "index_subscriptions_on_user_id_and_status"
    t.index ["user_id"], name: "index_subscriptions_on_user_id"
    t.check_constraint "billing_cycle::text = ANY (ARRAY['monthly'::character varying, 'yearly'::character varying]::text[])", name: "check_subscriptions_billing_cycle"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying, 'canceled'::character varying, 'incomplete'::character varying, 'incomplete_expired'::character varying, 'past_due'::character varying, 'trialing'::character varying, 'unpaid'::character varying]::text[])", name: "check_subscriptions_status"
  end

  create_table "system_settings", primary_key: "key", id: { type: :string, limit: 100 }, force: :cascade do |t|
    t.text "value", null: false
    t.text "description"
    t.boolean "is_public", default: false
    t.datetime "updated_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.index ["is_public"], name: "index_system_settings_on_is_public"
    t.index ["updated_at"], name: "index_system_settings_on_updated_at"
  end

  create_table "todos", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "title"
    t.text "description"
    t.date "deadline"
    t.integer "priority"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "status"
    t.index ["user_id"], name: "index_todos_on_user_id"
  end

  create_table "user_settings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "setting_key", limit: 100, null: false
    t.text "setting_value", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_user_settings_on_created_at"
    t.index ["setting_key"], name: "index_user_settings_on_setting_key"
    t.index ["user_id", "setting_key"], name: "index_user_settings_unique", unique: true
    t.index ["user_id"], name: "index_user_settings_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.string "username"
    t.string "provider", null: false
    t.string "uid", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "avatar_url"
    t.string "stripe_customer_id", limit: 255
    t.string "timezone", limit: 50, default: "Asia/Tokyo"
    t.string "language", limit: 10, default: "ja"
    t.boolean "is_active", default: true
    t.datetime "email_verified_at", precision: nil
    t.datetime "last_login_at", precision: nil
    t.datetime "deleted_at"
    t.boolean "slack_notification_enabled", default: false, null: false
    t.string "slack_webhook_url"
    t.string "billing_status", default: "false"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["is_active"], name: "index_users_on_is_active"
    t.index ["provider", "uid"], name: "index_users_on_provider_and_uid", unique: true
    t.index ["stripe_customer_id"], name: "index_users_on_stripe_customer_id", unique: true, where: "(stripe_customer_id IS NOT NULL)"
  end

  create_table "work_log_kpt_links", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "work_log_id", null: false
    t.uuid "kpt_session_id", null: false
    t.integer "relevance_score"
    t.text "notes"
    t.datetime "created_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.index ["created_at"], name: "index_work_log_kpt_links_on_created_at"
    t.index ["kpt_session_id"], name: "index_work_log_kpt_links_on_kpt_session_id"
    t.index ["relevance_score"], name: "index_work_log_kpt_links_on_relevance_score"
    t.index ["work_log_id", "kpt_session_id"], name: "index_work_log_kpt_links_unique", unique: true
    t.index ["work_log_id"], name: "index_work_log_kpt_links_on_work_log_id"
    t.check_constraint "relevance_score >= 1 AND relevance_score <= 5", name: "check_work_log_kpt_links_relevance_score"
  end

  create_table "work_logs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "title", limit: 200, null: false
    t.text "description"
    t.string "category", limit: 100
    t.string "project_name", limit: 100
    t.datetime "started_at", precision: nil, null: false
    t.datetime "ended_at", precision: nil
    t.integer "mood_score"
    t.integer "productivity_score"
    t.integer "difficulty_score"
    t.text "tags", default: [], array: true
    t.text "notes"
    t.string "location", limit: 100
    t.boolean "is_billable", default: false
    t.string "status", limit: 20, default: "completed"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.virtual "duration_minutes", type: :integer, as: "\nCASE\n    WHEN (ended_at IS NOT NULL) THEN (EXTRACT(epoch FROM (ended_at - started_at)) / (60)::numeric)\n    ELSE NULL::numeric\nEND", stored: true
    t.index ["category"], name: "index_work_logs_on_category"
    t.index ["duration_minutes"], name: "index_work_logs_on_duration_minutes"
    t.index ["ended_at"], name: "index_work_logs_on_ended_at"
    t.index ["is_billable"], name: "index_work_logs_on_is_billable"
    t.index ["project_name"], name: "index_work_logs_on_project_name"
    t.index ["started_at", "ended_at"], name: "index_work_logs_on_started_at_and_ended_at"
    t.index ["started_at"], name: "index_work_logs_on_started_at"
    t.index ["status"], name: "index_work_logs_on_status"
    t.index ["tags"], name: "index_work_logs_on_tags", using: :gin
    t.index ["user_id"], name: "index_work_logs_on_user_id"
    t.check_constraint "difficulty_score >= 1 AND difficulty_score <= 5", name: "check_work_logs_difficulty_score"
    t.check_constraint "mood_score >= 1 AND mood_score <= 5", name: "check_work_logs_mood_score"
    t.check_constraint "productivity_score >= 1 AND productivity_score <= 5", name: "check_work_logs_productivity_score"
    t.check_constraint "status::text = ANY (ARRAY['in_progress'::character varying, 'completed'::character varying, 'paused'::character varying, 'cancelled'::character varying]::text[])", name: "check_work_logs_status"
  end

  add_foreign_key "authentications", "users"
  add_foreign_key "charts", "users"
  add_foreign_key "feedbacks", "feedback_priorities"
  add_foreign_key "feedbacks", "feedback_types"
  add_foreign_key "feedbacks", "users"
  add_foreign_key "github_issues", "users"
  add_foreign_key "goals", "users"
  add_foreign_key "insights", "kpt_sessions"
  add_foreign_key "insights", "users"
  add_foreign_key "kpt_items", "kpt_sessions"
  add_foreign_key "kpt_reviews", "users"
  add_foreign_key "kpt_sessions", "users"
  add_foreign_key "notifications", "users"
  add_foreign_key "payment_methods", "users"
  add_foreign_key "payments", "subscriptions"
  add_foreign_key "payments", "users"
  add_foreign_key "reflection_marks", "users"
  add_foreign_key "subscriptions", "users"
  add_foreign_key "todos", "users"
  add_foreign_key "user_settings", "users"
  add_foreign_key "work_log_kpt_links", "kpt_sessions"
  add_foreign_key "work_log_kpt_links", "work_logs"
  add_foreign_key "work_logs", "users"
end
