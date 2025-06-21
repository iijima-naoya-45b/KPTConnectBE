class Api::V1::ContactsController < ApplicationController
  # お問い合わせは認証不要のため、before_actionを設定しない

  # POST /api/v1/contacts
  def create
    contact_params = params.require(:contact).permit(:name, :email, :subject, :message)
    
    # バリデーション
    unless valid_contact_params?(contact_params)
      render json: { error: '必須項目が不足しています' }, status: :bad_request
      return
    end

    # メール送信
    begin
      # ユーザー宛の確認メール（非同期）
      ContactMailer.contact_confirmation(contact_params).deliver_later
      
      # 管理者宛の通知メール（非同期）
      ContactMailer.contact_notification(contact_params).deliver_later
      
      render json: { 
        message: 'お問い合わせを受け付けました。確認メールをお送りしましたのでご確認ください。',
        status: 'success'
      }, status: :ok
      
    rescue => e
      Rails.logger.error "Contact mail delivery failed: #{e.message}"
      render json: { 
        error: 'メール送信に失敗しました。しばらく時間をおいて再度お試しください。',
        status: 'error'
      }, status: :internal_server_error
    end
  end

  private

  def valid_contact_params?(params)
    params[:name].present? && 
    params[:email].present? && 
    params[:subject].present? && 
    params[:message].present? &&
    valid_email_format?(params[:email])
  end

  def valid_email_format?(email)
    email =~ /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i
  end
end 