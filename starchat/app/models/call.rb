class Call < ApplicationRecord
  STATUSES = %w[ringing in_progress completed no_answer failed].freeze
  TERMINAL_STATUSES = %w[completed no_answer failed].freeze

  store_accessor :meta, :conference_sid, :twilio_conference_sid, :recording_sid, :parent_call_sid, :initiated_at, :ended_at

  DISPLAY_DIRECTION = { 'incoming' => 'inbound', 'outgoing' => 'outbound' }.freeze

  DEFAULT_STUN_URL = 'stun:stun.l.google.com:19302'.freeze

  enum :provider, { twilio: 0, whatsapp: 1 }
  enum :direction, { incoming: 0, outgoing: 1 }

  belongs_to :account
  belongs_to :inbox
  belongs_to :conversation
  belongs_to :contact
  belongs_to :message, optional: true, inverse_of: :call
  belongs_to :accepted_by_agent, class_name: 'User', optional: true

  has_one_attached :recording

  validates :provider_call_id, presence: true
  validates :provider, presence: true
  validates :direction, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }

  scope :active, -> { where.not(status: TERMINAL_STATUSES) }
  scope :by_conference_sid, ->(sid) { where("meta->>'conference_sid' = ?", sid) }
  scope :by_twilio_conference_sid, ->(sid) { where("meta->>'twilio_conference_sid' = ?", sid) }

  def self.find_by_provider_call_id(provider, sid)
    find_by(provider: provider, provider_call_id: sid)
  end

  def default_conference_sid
    "conf_account_#{account_id}_call_#{id}"
  end

  def self.default_ice_servers
    urls = ENV.fetch('VOICE_CALL_STUN_URLS', DEFAULT_STUN_URL).split(',').filter_map { |u| u.strip.presence }
    [{ urls: urls }]
  end

  def direction_label
    DISPLAY_DIRECTION[direction]
  end

  def ringing?
    status == 'ringing'
  end

  def in_progress?
    status == 'in_progress'
  end

  def terminal?
    TERMINAL_STATUSES.include?(status)
  end

  def display_status
    status.to_s.tr('_', '-')
  end

  def from_number
    incoming? ? contact.phone_number : inbox.channel&.phone_number
  end

  def to_number
    incoming? ? inbox.channel&.phone_number : contact.phone_number
  end

  def recording_url
    return nil unless recording.attached?

    Rails.application.routes.url_helpers.rails_blob_url(recording)
  end

  def push_event_data
    {
      id: id,
      provider_call_id: provider_call_id,
      provider: provider,
      direction: direction,
      status: display_status,
      duration_seconds: duration_seconds,
      end_reason: end_reason,
      conference_sid: conference_sid,
      accepted_by_agent_id: accepted_by_agent_id,
      accepted_by_agent_name: accepted_by_agent&.available_name,
      started_at: started_at&.to_i,
      ended_at: ended_at,
      from_number: from_number,
      to_number: to_number,
      recording_url: recording_url,
      transcript: transcript
    }
  end
end
