# frozen_string_literal: true

# PostgreSQL拡張機能有効化マイグレーション
# UUID生成などに必要な拡張機能を有効化
class EnableExtensions < ActiveRecord::Migration[7.0]
  def change
    # UUIDを主キーとして使用するための設定
    enable_extension 'pgcrypto' unless extension_enabled?('pgcrypto')
  end
end
