class FeedbackMailer < ApplicationMailer
  default from: 'no-reply@kptconnect.com'

  # メール送信メソッド: ユーザーへの確認メール
  def feedback_confirmation(feedback)
    @feedback = feedback
    mail(to: @feedback.email, subject: 'フィードバックを受け付けました')
  end

  # メール送信メソッド: 管理者への通知メール
  def feedback_notification(feedback)
    @feedback = feedback
    mail(to: 'admin@kptconnect.com', subject: '新しいフィードバックが送信されました')
  end
end 