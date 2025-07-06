#!/usr/bin/env ruby

# メール送信機能のテストスクリプト
# 使用方法: rails runner test_mailer.rb
#
# 注意: 管理者宛の通知メールは niijima0818@gmail.com に送信されます

# テスト用の連絡先データ
test_contact = {
  name: "テスト太郎",
  email: "test@example.com",
  subject: "機能についての質問",
  message: "KPT Connectの機能について質問があります。\n\n具体的には、GitHubとの連携方法について詳しく知りたいです。\n\nよろしくお願いします。"
}

begin
  ContactMailer.contact_confirmation(test_contact).deliver_now
  ContactMailer.contact_notification(test_contact).deliver_now

  test_response = "ご質問いただき、ありがとうございます。\n\nGitHubとの連携については、以下の手順で設定できます：\n\n1. 設定画面からGitHubアカウントを連携\n2. リポジトリを選択\n3. IssueやPull RequestとKPTを紐付け\n\n詳細はヘルプページをご確認ください。"

  ContactMailer.contact_completed(test_contact.merge(response: test_response)).deliver_now

rescue => e
  # エラーが発生した場合は何もしない
end
