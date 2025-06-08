# frozen_string_literal: true

# 分析用ビュー作成マイグレーション
# よく使われるクエリの簡略化のためのビューを作成
class CreateAnalysisViews < ActiveRecord::Migration[7.0]
  def change
    reversible do |dir|
      dir.up do
        # ユーザーのKPT統計ビュー
        execute <<-SQL
          CREATE VIEW user_kpt_stats AS
          SELECT#{' '}
            u.id as user_id,
            u.name as user_name,
            COUNT(DISTINCT s.id) as total_sessions,
            COUNT(CASE WHEN i.type = 'keep' THEN 1 END) as keep_count,
            COUNT(CASE WHEN i.type = 'problem' THEN 1 END) as problem_count,
            COUNT(CASE WHEN i.type = 'try' THEN 1 END) as try_count,
            COUNT(CASE WHEN i.status = 'completed' THEN 1 END) as completed_items,
            AVG(i.emotion_score) as avg_emotion_score,
            AVG(i.impact_score) as avg_impact_score
          FROM users u
          LEFT JOIN kpt_sessions s ON u.id = s.user_id
          LEFT JOIN kpt_items i ON s.id = i.kpt_session_id
          GROUP BY u.id, u.name;
        SQL

        # 月別KPTトレンドビュー
        execute <<-SQL
          CREATE VIEW monthly_kpt_trends AS
          SELECT#{' '}
            user_id,
            DATE_TRUNC('month', session_date) as month,
            COUNT(DISTINCT s.id) as sessions_count,
            COUNT(CASE WHEN i.type = 'keep' THEN 1 END) as keep_count,
            COUNT(CASE WHEN i.type = 'problem' THEN 1 END) as problem_count,
            COUNT(CASE WHEN i.type = 'try' THEN 1 END) as try_count
          FROM kpt_sessions s
          LEFT JOIN kpt_items i ON s.id = i.kpt_session_id
          GROUP BY user_id, DATE_TRUNC('month', session_date)
          ORDER BY user_id, month;
        SQL

        # 作業ログ統計ビュー
        execute <<-SQL
          CREATE VIEW work_log_stats AS
          SELECT#{' '}
            user_id,
            DATE_TRUNC('week', started_at) as week,
            COUNT(*) as total_logs,
            SUM(duration_minutes) as total_duration_minutes,
            AVG(mood_score) as avg_mood_score,
            AVG(productivity_score) as avg_productivity_score,
            AVG(difficulty_score) as avg_difficulty_score,
            COUNT(CASE WHEN is_billable THEN 1 END) as billable_logs_count,
            SUM(CASE WHEN is_billable THEN duration_minutes ELSE 0 END) as billable_duration_minutes
          FROM work_logs
          WHERE ended_at IS NOT NULL
          GROUP BY user_id, DATE_TRUNC('week', started_at)
          ORDER BY user_id, week;
        SQL
      end

      dir.down do
        execute 'DROP VIEW IF EXISTS work_log_stats;'
        execute 'DROP VIEW IF EXISTS monthly_kpt_trends;'
        execute 'DROP VIEW IF EXISTS user_kpt_stats;'
      end
    end
  end
end
