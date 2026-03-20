module Channelable
  extend ActiveSupport::Concern
  included do
    validates :account_id, presence: true
    belongs_to :account
    has_one :inbox, as: :channel, dependent: :destroy_async, touch: true
    after_update :create_audit_log_entry
  end

  def create_audit_log_entry; end

  # Used by Monitoring::OperationalSnapshotBuilder to determine channel health.
  # Channels without explicit connection/authorization state should default to online.
  def monitoring_status
    'online'
  end
end

Channelable.prepend_mod_with('Channelable')
