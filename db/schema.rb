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

ActiveRecord::Schema[8.0].define(version: 2025_05_31_120014) do
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
    t.string "priority", limit: 10, default: "medium"
    t.string "status", limit: 20, default: "open"
    t.date "due_date"
    t.string "assigned_to", limit: 100
    t.integer "emotion_score"
    t.integer "impact_score"
    t.text "tags", default: [], array: true
    t.text "notes"
    t.datetime "completed_at", precision: nil
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["completed_at"], name: "index_kpt_items_on_completed_at"
    t.index ["due_date"], name: "index_kpt_items_on_due_date"
    t.index ["emotion_score"], name: "index_kpt_items_on_emotion_score"
    t.index ["impact_score"], name: "index_kpt_items_on_impact_score"
    t.index ["kpt_session_id"], name: "index_kpt_items_on_kpt_session_id"
    t.index ["priority"], name: "index_kpt_items_on_priority"
    t.index ["status"], name: "index_kpt_items_on_status"
    t.index ["tags"], name: "index_kpt_items_on_tags", using: :gin
    t.index ["type"], name: "index_kpt_items_on_type"
    t.check_constraint "emotion_score >= 1 AND emotion_score <= 5", name: "check_kpt_items_emotion_score"
    t.check_constraint "impact_score >= 1 AND impact_score <= 5", name: "check_kpt_items_impact_score"
    t.check_constraint "priority::text = ANY (ARRAY['low'::character varying, 'medium'::character varying, 'high'::character varying]::text[])", name: "check_kpt_items_priority"
    t.check_constraint "status::text = ANY (ARRAY['open'::character varying, 'in_progress'::character varying, 'completed'::character varying, 'cancelled'::character varying]::text[])", name: "check_kpt_items_status"
    t.check_constraint "type::text = ANY (ARRAY['keep'::character varying, 'problem'::character varying, 'try'::character varying]::text[])", name: "check_kpt_items_type"
  end

  create_table "kpt_sessions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "title", limit: 200, null: false
    t.text "description"
    t.date "session_date", default: -> { "CURRENT_DATE" }, null: false
    t.string "status", limit: 20, default: "draft"
    t.text "tags", default: [], array: true
    t.boolean "is_template", default: false
    t.string "template_name", limit: 100
    t.datetime "completed_at", precision: nil
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["completed_at"], name: "index_kpt_sessions_on_completed_at"
    t.index ["is_template"], name: "index_kpt_sessions_on_is_template"
    t.index ["session_date"], name: "index_kpt_sessions_on_session_date"
    t.index ["status"], name: "index_kpt_sessions_on_status"
    t.index ["tags"], name: "index_kpt_sessions_on_tags", using: :gin
    t.index ["user_id"], name: "index_kpt_sessions_on_user_id"
    t.check_constraint "status::text = ANY (ARRAY['draft'::character varying::text, 'in_progress'::character varying::text, 'completed'::character varying::text, 'archived'::character varying::text])", name: "check_kpt_sessions_status"
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
    t.string "name"
    t.text "avatar_url"
    t.string "stripe_customer_id", limit: 255
    t.string "timezone", limit: 50, default: "Asia/Tokyo"
    t.string "language", limit: 10, default: "ja"
    t.boolean "is_active", default: true
    t.datetime "email_verified_at", precision: nil
    t.datetime "last_login_at", precision: nil
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
  add_foreign_key "insights", "kpt_sessions"
  add_foreign_key "insights", "users"
  add_foreign_key "kpt_items", "kpt_sessions"
  add_foreign_key "kpt_sessions", "users"
  add_foreign_key "payment_methods", "users"
  add_foreign_key "payments", "subscriptions"
  add_foreign_key "payments", "users"
  add_foreign_key "subscriptions", "users"
  add_foreign_key "user_settings", "users"
  add_foreign_key "work_log_kpt_links", "kpt_sessions"
  add_foreign_key "work_log_kpt_links", "work_logs"
  add_foreign_key "work_logs", "users"
end
