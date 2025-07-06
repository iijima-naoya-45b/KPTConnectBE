# WebhookController
#
# This controller handles incoming Stripe webhook events.
#
# Events Handled:
#
# - customer.subscription.updated
#   - id: Subscription ID
#   - status: Subscription status (e.g., active, canceled, past_due)
#   - current_period_start: Start date of the current billing period
#   - current_period_end: End date of the current billing period
#   - items: List of items in the subscription
#
# - customer.subscription.deleted
#   - id: Subscription ID
#   - status: Typically canceled
#   - canceled_at: Date and time when the subscription was canceled
#
# - invoice.payment_failed
#   - id: Invoice ID
#   - amount_due: Amount due for payment
#   - currency: Currency
#   - customer: Customer ID
#   - attempt_count: Number of payment attempts
#   - next_payment_attempt: Date and time of the next payment attempt
#
# - customer (originally checkout.session.completed)
#   - id: Session ID
#   - customer: Customer ID
#   - payment_status: Payment status (e.g., paid, unpaid)
#
class WebhookController < ApplicationController
  # skip_before_action :verify_authenticity_token

  def receive
    payload = request.body.read
    event = nil

    begin
      event = Stripe::Event.construct_from(
        JSON.parse(payload, symbolize_names: true)
      )
    rescue JSON::ParserError => e
      render json: { error: 'Invalid payload' }, status: 400
      return
    end

    case event.type
    when 'customer.subscription.updated'
      subscription = event.data.object
      user = User.find_by(stripe_customer_id: subscription.customer)
      if user
        user.update(billing_status: 'true')
      end
    when 'customer.subscription.deleted'
      subscription = event.data.object
      user = User.find_by(stripe_customer_id: subscription.customer)
      if user
        user.update(billing_status: 'false')
      end
    when 'invoice.payment_failed'
      invoice = event.data.object
      user = User.find_by(stripe_customer_id: invoice.customer)
      if user
        user.update(billing_status: 'false')
      end
    when 'customer'
      session = event.data.object
      user = User.find_by(stripe_customer_id: session.customer)
      if user
        user.update(billing_status: 'true')
      end
    else
      render json: { error: 'Unhandled event type' }, status: 400
      return
    end

    render json: { message: 'Success' }, status: 200
  end
end 