# frozen_string_literal: true

class RemoveStatusAndPriorityFromKptItems < ActiveRecord::Migration[8.0]
  def up
    # 依存するビューを先に削除
    execute "DROP VIEW IF EXISTS user_kpt_stats;"

    # 既存のCHECK制約を削除
    execute <<-SQL
      ALTER TABLE kpt_items DROP CONSTRAINT IF EXISTS check_kpt_items_priority;
    SQL

    # カラムを削除
    if column_exists?(:kpt_items, :status)
      remove_column :kpt_items, :status
    end
    if column_exists?(:kpt_items, :priority)
      remove_column :kpt_items, :priority
    end

    # statusとpriorityを除外してビューを再作成
    execute <<-SQL
      CREATE VIEW user_kpt_stats AS
      SELECT#{' '}
        u.id as user_id,
        COALESCE(u.username, u.email) as user_name,
        COUNT(DISTINCT s.id) as total_sessions,
        COUNT(CASE WHEN i.type = 'keep' THEN 1 END) as keep_count,
        COUNT(CASE WHEN i.type = 'problem' THEN 1 END) as problem_count,
        COUNT(CASE WHEN i.type = 'try' THEN 1 END) as try_count,
        AVG(i.emotion_score) as avg_emotion_score,
        AVG(i.impact_score) as avg_impact_score
      FROM users u
      LEFT JOIN kpt_sessions s ON u.id = s.user_id
      LEFT JOIN kpt_items i ON s.id = i.kpt_session_id
      GROUP BY u.id, COALESCE(u.username, u.email);
    SQL
  end

  def down
    # ビューを削除
    execute "DROP VIEW IF EXISTS user_kpt_stats;"

    # カラムを再追加
    add_column :kpt_items, :priority, :string, limit: 10, default: "medium"
    add_column :kpt_items, :status, :string, limit: 20, default: "open"

    # CHECK制約を再追加
    execute <<-SQL
      ALTER TABLE kpt_items
      ADD CONSTRAINT check_kpt_items_priority
      CHECK (priority IN ('low', 'medium', 'high'));
    SQL

    # 元のビューを再作成
    execute <<-SQL
      CREATE VIEW user_kpt_stats AS
      SELECT#{' '}
        u.id as user_id,
        COALESCE(u.username, u.email) as user_name,
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
      GROUP BY u.id, COALESCE(u.username, u.email);
    SQL
  end
end
