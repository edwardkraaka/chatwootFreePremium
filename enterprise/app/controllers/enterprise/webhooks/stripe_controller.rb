class Enterprise::Webhooks::StripeController < ActionController::API
  def process_payload
    # Bypass all Stripe webhook processing - always return success
    # This prevents any subscription-based feature changes
    head :ok
  end
end
