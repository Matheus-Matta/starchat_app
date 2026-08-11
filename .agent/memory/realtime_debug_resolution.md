# Post-Mortem: Realtime Message Updates & Status Bugs

**Date:** 2025-12-19
**Context:** Starchats / Evolution API Integration

## Symptoms

1. **No Realtime Updates:** Incoming messages were saved to DB but did not appear on frontend (Vue.js) without a page refresh.
2. **Status Updates Failed:** Even after messages appeared, status changes (sent -> delivered -> read) were not reflected in realtime.
3. **Redis Timeouts:** Logs showed frequent `RedisClient::ReadTimeoutError`.

## Root Causes

### 1. Environment Mismatch (Infrastructure)

- **The Issue:** The User was running the Rails Server in `development` mode (default) but the Sidekiq Worker in `production` mode (`bundle exec sidekiq -e production`).
- **Impact:** ActionCable uses Redis Pub/Sub channels prefixed with the environment name (e.g., `chatwoot_development_action_cable`).
  - Sidekiq (Prod) published updates to `chatwoot_production_action_cable`.
  - Rails (Dev) listened on `chatwoot_development_action_cable`.
  - **Result:** The frontend never received the events.

### 2. Payload Type Mismatch (Code/Frontend Contract)

- **The Issue:** Modifications to `app/models/message.rb` changed `push_event_data` to send all enums as integers (`before_type_cast`) or strings indiscriminately.
- **Impact:**
  - **Message Type:** Frontend expects **Integer** (`0` for incoming, `1` for outgoing).
  - **Status:** Frontend expects **String** (`'sent'`, `'delivered'`) based on `MESSAGE_STATUS` constants in `app/javascript/shared/constants/messages.js`.
  - **Result:** When sending `status: 1` (integer), the frontend comparison `start === 'delivered'` failed silently, ignoring the update.

## Resolution

### 1. Unified Redis Channel

- **Action:** Modified `config/cable.yml` to remove the environment dependency from `channel_prefix`.
- **Code:** Changed `<%= "starchats_#{Rails.env}_action_cable" %>` to `starchats_action_cable`.
- **Effect:** Rails and Sidekiq now communicate on the same channel regardless of their individual `Rails.env` settings.

### 2. Precise Payload Serialization

- **Action:** Updated `Message#push_event_data` in `app/models/message.rb`.
- **Code:**
  ```ruby
  data = attributes.symbolize_keys.merge(
    created_at: created_at.to_i,
    message_type: message_type_before_type_cast, # Keep as Integer for Frontend Logic
    status: status,                              # Keep as String for Frontend UI/Constants
    content_type: content_type,                  # Keep as String
    # ...
  )
  ```
- **Effect:** Payloads now perfectly match the specific strict-type expectations of the legacy Vue.js frontend.

## Prevention

- **Always** verify `config/cable.yml` channel prefixes when debugging Redis Pub/Sub issues across environments.
- **Always** check `app/javascript/shared/constants` or frontend store actions to confirm expected data types (String vs Integer) for Enums before refactoring Model serialization.
