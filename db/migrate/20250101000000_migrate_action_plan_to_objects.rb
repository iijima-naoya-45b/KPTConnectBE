# frozen_string_literal: true

# アクションプランを文字列配列からオブジェクト配列に変換するマイグレーション
class MigrateActionPlanToObjects < ActiveRecord::Migration[8.0]
  def up
    # 既存のaction_planデータを変換
    execute <<-SQL
      UPDATE goals#{' '}
      SET action_plan = (
        SELECT json_agg(
          json_build_object(
            'id', 'action_' || row_num::text,
            'title', action_item,
            'progress', 0
          )
        )
        FROM (
          SELECT action_item, row_number() OVER () as row_num
          FROM json_array_elements_text(action_plan) AS action_item
        ) numbered_actions
      )
      WHERE action_plan IS NOT NULL#{' '}
        AND json_typeof(action_plan) = 'array'
        AND json_array_length(action_plan) > 0
        AND json_typeof(action_plan->0) = 'string';
    SQL
  end

  def down
    # ダウングレード時は文字列配列に戻す
    execute <<-SQL
      UPDATE goals#{' '}
      SET action_plan = (
        SELECT json_agg(action_item->>'title')
        FROM json_array_elements(action_plan) AS action_item
      )
      WHERE action_plan IS NOT NULL#{' '}
        AND json_typeof(action_plan) = 'array'
        AND json_array_length(action_plan) > 0
        AND json_typeof(action_plan->0) = 'object';
    SQL
  end
end
