require 'stripe'

class Api::V1::PaymentsController < ApplicationController
  Stripe.api_key = ENV['STRIPE_SECRET_KEY']

  def create_payment_intent
    begin
      amount_in_yen = 1000
      currency_code = 'jpy'

      payment_intent = Stripe::PaymentIntent.create(
        amount: amount_in_yen,
        currency: currency_code,
        payment_method_types: ['card'],
        description: 'Subscription payment for Pro Plan',
        metadata: { user_id: current_user.id }
      )
      render json: { clientSecret: payment_intent.client_secret }
    rescue Stripe::StripeError => e
      render json: { error: e.message }, status: :bad_request
    rescue => e
      render json: { error: e.message }, status: :bad_request
    end
  end

  def create_subscription
    begin
      logger.info "Starting subscription creation for user: \\#{current_user.id}"

      amount_in_yen = 1000
      currency_code = 'jpy'

      logger.info "Creating Stripe customer for user: \\#{current_user.email}"
      customer = Stripe::Customer.create({
        email: current_user.email,
        source: params[:stripeToken]
      })

      logger.info "Creating subscription for customer: \\#{customer.id}"
      subscription = Stripe::Subscription.create({
        customer: customer.id,
        items: [{ price: 'price_1RhgR3B62kIobqxBmayTUyUv' }],
        expand: ['latest_invoice.payment_intent'],
      })

      logger.info "Subscription created successfully: \\#{subscription.id}"
      render json: { subscriptionId: subscription.id, clientSecret: subscription.latest_invoice.payment_intent.client_secret }
    rescue Stripe::StripeError => e
      logger.error "Stripe error during subscription creation: \\#{e.message}"
      render json: { error: e.message }, status: :bad_request
    rescue => e
      logger.error "General error during subscription creation: \\#{e.message}"
      render json: { error: e.message }, status: :bad_request
    end
  end
end

