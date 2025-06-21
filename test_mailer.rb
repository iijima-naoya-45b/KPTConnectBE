#!/usr/bin/env ruby

# メール送信機能のテストスクリプト
# 使用方法: rails runner test_mailer.rb
# 
# 注意: 管理者宛の通知メールは niijima0818@gmail.com に送信されます

puts "=== KPT Connect メール送信テスト ==="
puts "管理者宛通知メール送信先: niijima0818@gmail.com"
puts ""

# テスト用の連絡先データ
test_contact = {
  name: "テスト太郎",
  email: "test@example.com",
  subject: "機能についての質問",
  message: "KPT Connectの機能について質問があります。\n\n具体的には、GitHubとの連携方法について詳しく知りたいです。\n\nよろしくお願いします。"
}

puts "テストデータ:"
puts "名前: #{test_contact[:name]}"
puts "メール: #{test_contact[:email]}"
puts "件名: #{test_contact[:subject]}"
puts "メッセージ: #{test_contact[:message]}"
puts ""

begin
  puts "1. ユーザー宛確認メールを送信中..."
  ContactMailer.contact_confirmation(test_contact).deliver_now
  puts "✅ 確認メール送信成功"
  
  puts "2. 管理者宛通知メールを送信中..."
  ContactMailer.contact_notification(test_contact).deliver_now
  puts "✅ 通知メール送信成功"
  
  puts "3. 回答メールを送信中..."
  test_response = "ご質問いただき、ありがとうございます。\n\nGitHubとの連携については、以下の手順で設定できます：\n\n1. 設定画面からGitHubアカウントを連携\n2. リポジトリを選択\n3. IssueやPull RequestとKPTを紐付け\n\n詳細はヘルプページをご確認ください。"
  
  ContactMailer.contact_completed(test_contact.merge(response: test_response)).deliver_now
  puts "✅ 回答メール送信成功"
  
  puts ""
  puts "🎉 すべてのメール送信テストが成功しました！"
  puts ""
  puts "開発環境では、letter_opener gemによりブラウザでメールが開かれます。"
  puts "メールの内容とデザインをご確認ください。"
  
rescue => e
  puts "❌ エラーが発生しました: #{e.message}"
  puts e.backtrace.first(5)
end 