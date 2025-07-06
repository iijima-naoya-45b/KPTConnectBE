class ContactMailer < ApplicationMailer
  # お問い合わせ確認メール（ユーザー宛）
  def contact_confirmation(contact_params)
    @name = contact_params[:name]
    @email = contact_params[:email]
    @subject = contact_params[:subject]
    @message = contact_params[:message]

    mail(
      to: @email,
      subject: "【KPT Connect】お問い合わせを受け付けました",
      from: "KPT Connect <#{ENV['FROM_EMAIL'] || 'noreply@kpt-connect.biz'}>"
    )
  end

  # お問い合わせ通知メール（管理者宛）
  def contact_notification(contact_params)
    @name = contact_params[:name]
    @email = contact_params[:email]
    @subject = contact_params[:subject]
    @message = contact_params[:message]
    @timestamp = Time.current.strftime("%Y年%m月%d日 %H:%M:%S")

    mail(
      to: "kptconnect.biz@gmail.com",  # 固定の送信先
      subject: "【KPT Connect】新しいお問い合わせ: #{@subject}",
      from: "#{@name} <#{@email}>",  # ユーザーが入力した名前とメールアドレス
      reply_to: "#{@name} <#{@email}>"  # 返信先もユーザーのメールアドレス
    )
  end

  # お問い合わせ完了メール（ユーザー宛）
  def contact_completed(contact_params)
    @name = contact_params[:name]
    @email = contact_params[:email]
    @subject = contact_params[:subject]
    @message = contact_params[:message]
    @response = contact_params[:response] || "お問い合わせいただき、ありがとうございます。内容を確認の上、担当者より回答いたします。"

    mail(
      to: @email,
      subject: "【KPT Connect】お問い合わせへの回答",
      from: "KPT Connect <#{ENV['FROM_EMAIL'] || 'noreply@kpt-connect.biz'}>"
    )
  end
end
