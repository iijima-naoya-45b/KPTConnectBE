class CheckoutController < ApplicationController
  require "stripe"

  Stripe.api_key = ENV["STRIPE_SECRET_KEY"]

  def create
    user = User.find_by(id: current_user.id)
    if user.billing_status == "active"
      render json: { error: "Already subscribed" }, status: 400
      return
    end

    # プラン情報を定義
    plan = { name: "Pro Plan", amount: 500 }

    session = Stripe::Checkout::Session.create(
      payment_method_types: [ "card" ],
      line_items: [ {
        price_data: {
          currency: "jpy",
          unit_amount: plan[:amount]
        }
      } ],
      mode: "payment",
      success_url: success_url,
      cancel_url: cancel_url,
    )

    render json: { id: session.id }
  end

  private

  def success_url
    "https://yourdomain.com/success"
  end

  def cancel_url
    "https://yourdomain.com/cancel"
  end
end
