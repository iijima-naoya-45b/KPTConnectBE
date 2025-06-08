#!/usr/bin/env ruby

# JWT機能テストスクリプト
require_relative 'config/environment'

puts "=== JWT機能テスト ==="
puts "Rails環境: #{Rails.env}"
puts "Secret key base exists: #{Rails.application.credentials.secret_key_base.present?}"
puts "Secret key base (first 10 chars): #{Rails.application.credentials.secret_key_base&.first(10)}..."

# JWT生成テスト
begin
  test_payload = { user_id: 123, test: true }
  token = JsonWebToken.encode(test_payload)
  puts "✅ JWT生成成功: #{token[0..20]}..."

  # JWT復号化テスト
  decoded = JsonWebToken.decode(token)
  puts "✅ JWT復号化成功: #{decoded}"

  if decoded[:user_id] == 123
    puts "✅ ペイロード検証成功"
  else
    puts "❌ ペイロード検証失敗"
  end

rescue => e
  puts "❌ JWTテスト失敗: #{e.message}"
  puts "エラー詳細: #{e.backtrace.first(3).join("\n")}"
end

# 環境変数確認
puts "\n=== 環境変数確認 ==="
puts "GOOGLE_KEY: #{ENV['GOOGLE_KEY'].present? ? '設定済み' : '未設定'}"
puts "GOOGLE_SECRET: #{ENV['GOOGLE_SECRET'].present? ? '設定済み' : '未設定'}"
puts "FRONTEND_URL: #{ENV['FRONTEND_URL']}"
