require 'rails_helper'

describe Enterprise::Billing::ReconcilePlanFeaturesService do
  let(:account) { create(:account) }

  describe '#perform' do
    it 'does not change premium feature grants when the account plan changes' do
      account.enable_features!('audit_logs', 'campaign_analytics', 'conversation_monitors')
      account.update!(custom_attributes: { 'plan_name' => 'Hacker', 'subscription_status' => 'active' })

      result = described_class.new(account: account).perform

      expect(result).to be(true)
      expect(account.reload).to be_feature_enabled('audit_logs')
      expect(account).to be_feature_enabled('campaign_analytics')
      expect(account).to be_feature_enabled('conversation_monitors')
    end

    it 'does not remove features during Shopify lifecycle cleanup' do
      account.enable_features!('audit_logs', 'saml', 'captain_classifier')
      account.update!(
        internal_attributes: { 'billing_provider' => 'shopify' },
        custom_attributes: { 'plan_name' => nil }
      )

      described_class.new(account: account, shopify_lifecycle_cleanup: true).perform

      expect(account.reload).to be_feature_enabled('audit_logs')
      expect(account).to be_feature_enabled('saml')
      expect(account).to be_feature_enabled('captain_classifier')
    end
  end
end
