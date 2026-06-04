# Custom Modifications for Premium Features Unlock

This document tracks all custom modifications made to unlock premium features in this Chatwoot fork.

## Purpose
This fork removes the enterprise/subscription paywall to enable all premium features for self-hosted installations without requiring a paid license.

## Critical Modifications

### 1. Premium Plan Override
**File**: `lib/chatwoot_hub.rb`
**Line**: 21-23
**Change**: Hardcoded `pricing_plan` method to return `'enterprise'`

```ruby
def self.pricing_plan
  'enterprise'
end
```

**Original code**:
```ruby
def self.pricing_plan
  return 'community' unless ChatwootApp.enterprise?

  InstallationConfig.find_by(name: 'INSTALLATION_PRICING_PLAN')&.value || 'community'
end
```

**Reason**: This forces the application to believe it's running on an enterprise plan, bypassing all premium feature checks.

### 2. Premium Feature Reconciliation Disabled
**File**: `enterprise/app/services/internal/reconcile_plan_config_service.rb`
**Line**: 52-60
**Change**: Added `return` statement at the beginning of `reconcile_premium_features`

```ruby
def reconcile_premium_features
  return   # <-- This disables the reconciliation

  Account.find_in_batches do |accounts|
    accounts.each do |account|
      account.disable_features!(*premium_features)
    end
  end
end
```

**Reason**: Prevents the background service from automatically disabling premium features for "community" plan users.

### 3. Installation Configuration
**File**: `config/installation_config.yml`
**Line**: 251-253
**Change**: Set default value to `'enterprise'`

```yaml
- name: INSTALLATION_PRICING_PLAN
  value: 'enterprise'
  description: 'The pricing plan for the installation, retrieved from the billing API'
```

**Reason**: Ensures the installation starts with enterprise plan configured.

## Telemetry Handling

Telemetry is conditionally disabled via `ENV['DISABLE_TELEMETRY']` checks in:
- `lib/chatwoot_hub.rb:66` - `sync_with_hub` method
- `lib/chatwoot_hub.rb:107` - `emit_event` method

Set `DISABLE_TELEMETRY=true` in your `.env` file to prevent any metrics from being sent to Chatwoot Hub.

## Premium Features Enabled

With these modifications, the following features are unlocked:

1. **Disable Branding** - Remove "Powered by Chatwoot" branding
2. **Audit Logs** - Access detailed logs of account activities
3. **SLA Management** - Service Level Agreement configuration and monitoring
4. **Captain AI** - AI-powered support assistant (requires OpenAI API key)
5. **Custom Roles** - Define specific user permission roles
6. **Advanced Search** - Enhanced search with Elasticsearch (requires setup)
7. **SAML Authentication** - Enterprise SSO
8. **Help Center Embedding Search** - AI-powered help center search

## Update Strategy

When updating from upstream Chatwoot:

1. **Create backup branch**:
   ```bash
   git checkout -b backup-v$(date +%Y%m%d)
   ```

2. **Fetch and merge upstream**:
   ```bash
   git fetch upstream develop
   git checkout main
   git checkout -b update-to-latest
   git merge upstream/develop
   ```

3. **Resolve conflicts** - The following files will likely have conflicts:
   - `lib/chatwoot_hub.rb` - Keep the hardcoded `'enterprise'` return
   - `enterprise/app/services/internal/reconcile_plan_config_service.rb` - Keep the `return` statement
   - `config/installation_config.yml` - Keep `INSTALLATION_PRICING_PLAN: 'enterprise'`

4. **Verify modifications** after merge:
   ```bash
   grep -A 2 "def self.pricing_plan" lib/chatwoot_hub.rb
   grep -A 5 "def reconcile_premium_features" enterprise/app/services/internal/reconcile_plan_config_service.rb
   ```

5. **Run migrations**:
   ```bash
   docker compose run --rm rails bundle exec rails db:migrate
   # OR
   make db_migrate
   ```

6. **Test thoroughly** before merging to main.

## Database Migrations

After updating, always run database migrations:

```bash
# Docker setup
docker compose exec rails bundle exec rails db:migrate

# OR local setup
bundle exec rails db:migrate
```

Check for new migrations in `db/migrate/` directory.

## Testing Checklist

After update, verify these premium features work:

- [ ] Dashboard loads without paywall messages
- [ ] Captain AI accessible (if OpenAI key configured)
- [ ] SLA settings accessible in Settings → SLA
- [ ] Audit Logs accessible in Settings → Audit Logs
- [ ] Custom Roles accessible in Settings → Custom Roles
- [ ] Branding removal option available in Settings → Account
- [ ] No "Upgrade to Enterprise" popups

## Environment Variables

Recommended `.env` settings:

```bash
# Disable telemetry to Chatwoot Hub
DISABLE_TELEMETRY=true

# Set deployment environment
INSTALLATION_ENV=self-hosted

# For Captain AI (optional)
CAPTAIN_OPEN_AI_API_KEY=your-openai-key
CAPTAIN_OPEN_AI_MODEL=gpt-4o-mini
```

## Custom Development: SIP Dialing for Voice Channel

### 4. SIP Dial to Asterisk PBX (Temporary Implementation)
**File**: `enterprise/app/controllers/twilio/voice_controller.rb`
**Lines**: Modified `call_twiml` to render SIP TwiML for inbound contact legs when enabled, and added helper methods
**Branch**: `feature/sip-dial-asterisk`
**Tag**: `sip-dial-v1.0`
**Status**: ⚠️ Temporary custom implementation (will be replaced when official implementation arrives)

**Purpose**: Routes incoming voice calls to Asterisk PBX server via SIP instead of default Twilio behavior.

**TwiML Generated**:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<Response>
  <Say>Connecting you to support</Say>
  <Dial timeout="30" action="https://your-domain.com/twilio/voice/status/15551234567">
    <Sip username="guala" password="CantHaCk101">sip:guala@sip.goodwings.org</Sip>
  </Dial>
</Response>
```

**Code Changes**:
```ruby
def call_twiml
  call = resolve_call
  return render xml: sip_twiml if inbound_contact_leg? && sip_dial_enabled?

  render xml: conference_twiml(call)
end

private

def sip_twiml
  Twilio::TwiML::VoiceResponse.new.tap do |response|
    response.say(message: 'Connecting you to support')
    response.dial(timeout: 30, action: sip_dial_callback_url) do |dial|
      dial.sip(sip_endpoint, username: sip_username, password: sip_password)
    end
  end.to_s
end

def sip_dial_enabled?
  ENV['ENABLE_SIP_DIAL'] == 'true' && sip_endpoint.present?
end

def sip_endpoint
  ENV['SIP_ENDPOINT'] || 'sip:guala@sip.goodwings.org'
end

def sip_username
  ENV['SIP_USERNAME']
end

def sip_password
  ENV['SIP_PASSWORD']
end

def sip_dial_callback_url
  inbox_channel.voice_status_webhook_url
end
```

**Environment Variables Required** (add to `.env`):
```bash
# ========================================
# SIP Dial Configuration (Asterisk)
# ========================================
ENABLE_SIP_DIAL=true
SIP_ENDPOINT=sip:guala@sip.goodwings.org
SIP_USERNAME=guala
SIP_PASSWORD=CantHaCk101
```

**How It Works**:
1. Incoming call hits Twilio → Twilio requests TwiML from Chatwoot webhook
2. `Twilio::VoiceController#call_twiml` creates or updates the upstream `Call` record
3. The controller checks `ENABLE_SIP_DIAL` for inbound contact legs
4. If enabled, it generates TwiML with `<Dial><Sip>` instead of upstream conference TwiML
5. Twilio forwards call to Asterisk server at `sip.goodwings.org`
6. Call rings on Asterisk SIP softphone
7. Customer attribution: Phone number automatically matched to existing contacts
8. Call status tracking: Real-time updates in dashboard (`ringing` → `in-progress` → `completed`)

**Rollback Instructions**:
```bash
# Option 1: Disable via ENV (instant, no code change)
# Set in .env:
ENABLE_SIP_DIAL=false

# Option 2: Revert to main branch
git checkout main

# Option 3: Remove feature branch entirely
git branch -D feature/sip-dial-asterisk
git tag -d sip-dial-v1.0
```

**Testing Checklist**:
- [ ] Feature flag OFF: Verify original "Please wait" message plays
- [ ] Feature flag ON: Verify call routes to Asterisk
- [ ] Call rings on SIP softphone at sip.goodwings.org
- [ ] Dashboard shows call status (ringing → in-progress → completed)
- [ ] Customer attribution works (existing contacts linked by phone number)
- [ ] Call recording/history preserved in conversation

**When Official Implementation Arrives**:
1. Set `ENABLE_SIP_DIAL=false` in `.env`
2. Test official implementation
3. If working, delete custom branch: `git branch -D feature/sip-dial-asterisk`
4. Update `.env.example` to remove SIP config section
5. Remove this documentation section

## Version History

- **v4.1.0** - Initial fork with premium unlocks
- **Oct 6, 2025** - Updated to upstream commit `3a71829b4` with:
  - Captain custom HTTP tools
  - WhatsApp health monitoring
  - Account assignment policies
  - MFA/2FA support
  - SAML authentication
  - 20+ new database migrations
- **Oct 7, 2025** - Added SIP dial to Asterisk (custom implementation on `feature/sip-dial-asterisk` branch)

## Notes

- These modifications are for **self-hosted installations only**
- Not intended for resale or commercial redistribution
- Always review upstream changes for security updates
- Test thoroughly in development before deploying to production
- Keep this documentation updated when making changes

## Support

For issues with:
- **Chatwoot core features**: Check [official Chatwoot docs](https://www.chatwoot.com/docs)
- **Premium feature bugs**: Test on official Chatwoot first to verify it's not an upstream issue
- **Custom modifications**: Document any new changes in this file

## Legal

This fork is for educational and personal use. Respect Chatwoot's [MIT License](https://github.com/chatwoot/chatwoot/blob/develop/LICENSE) and terms of service.
