#!/usr/bin/env ruby

# JWT機能テストスクリプト
require_relative 'config/environment'

# JWT生成テスト
begin
  test_payload = { user_id: 123, test: true }
  token = JsonWebToken.encode(test_payload)
  decoded = JsonWebToken.decode(token)
  
  # テスト結果の確認
  if decoded[:user_id] == 123
    # テスト成功
  else
    # テスト失敗
  end

rescue => e
  # エラーが発生した場合は何もしない
end
