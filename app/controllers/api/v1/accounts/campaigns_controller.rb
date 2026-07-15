class Api::V1::Accounts::CampaignsController < Api::V1::Accounts::BaseController
  include Campaigns::AudienceResolver

  before_action :campaign, except: [:index, :create, :preview_contacts, :match_contacts]
  before_action :check_authorization

  def index
    @campaigns = Current.account.campaigns
  end

  def show; end

  def create
    @campaign = Current.account.campaigns.create!(campaign_params_with_draft_status)
  end

  def update
    @campaign.update!(campaign_params)
  end

  def destroy
    @campaign.destroy!
    head :ok
  end

  def confirm
    raise Pundit::NotAuthorizedError unless @campaign.draft?

    @campaign.update!(campaign_status: :active)
  end

  def preview_contacts
    audience = parse_audience_param
    contacts = contacts_for_audience(Current.account, audience)

    page     = (params[:page] || 1).to_i
    per_page = 25
    total    = contacts.count
    paginated = contacts.page(page).per(per_page)

    render json: {
      count: total,
      contacts: paginated.map { |c| { id: c.id, name: c.name, email: c.email, phone_number: c.phone_number } },
      meta: { current_page: page, total_pages: (total.to_f / per_page).ceil }
    }
  end

  def match_contacts
    ids          = Array(params[:ids]).map(&:to_i).reject(&:zero?)
    identifiers  = Array(params[:identifiers]).map(&:to_s).map(&:strip).reject(&:blank?)
    emails       = Array(params[:emails]).map(&:to_s).map(&:strip).reject(&:blank?)
    phone_map    = build_phone_map(params[:phones], params[:phone_names]) # normalized_phone => name
    phones       = phone_map.keys

    base = Current.account.contacts
    scopes = []
    scopes << base.where(id: ids)                 if ids.any?
    scopes << base.where(identifier: identifiers) if identifiers.any?
    scopes << base.where(phone_number: phones)    if phones.any?
    scopes << base.where(email: emails)           if emails.any?

    contacts = scopes.reduce(Contact.none) { |acc, s| acc.or(s) }
    contacts = base.merge(contacts).to_a
    matched_count = contacts.count

    created = []
    if create_missing? && phones.any?
      missing_phones = phones - contacts.map(&:phone_number)
      created = create_contacts_from_phones(missing_phones, phone_map)
      contacts += created
    end

    input_count = (ids + identifiers + phones + emails).uniq.size

    render json: {
      contacts: contacts.map { |c| { id: c.id, name: c.name, email: c.email, phone_number: c.phone_number, identifier: c.identifier } },
      matched: matched_count,
      created: created.count,
      unmatched: [input_count - contacts.count, 0].max
    }
  end

  private

  def create_missing?
    ActiveModel::Type::Boolean.new.cast(params[:create_missing])
  end

  # Builds a map of normalized_phone => name from the incoming spreadsheet values.
  # phone_names is an optional { raw_phone => name } hash sent by the import modal.
  def build_phone_map(raw_phones, raw_names)
    names = raw_names.respond_to?(:to_unsafe_h) ? raw_names.to_unsafe_h : (raw_names || {})
    Array(raw_phones).each_with_object({}) do |raw, map|
      normalized = normalize_phone(raw)
      next if normalized.blank?

      map[normalized] ||= names[raw.to_s].presence
    end
  end

  # Normalizes a raw phone value to E.164 (+<digits>). Returns '' when no digits.
  def normalize_phone(raw)
    digits = raw.to_s.gsub(/[^\d+]/, '').delete('+')
    return '' if digits.blank?

    "+#{digits}"
  end

  def create_contacts_from_phones(phones, phone_map)
    phones.filter_map do |phone|
      # Skip values that can't satisfy the Contact E.164 validation
      next unless phone.match?(/\A\+[1-9]\d{1,14}\z/)

      name = phone_map[phone].presence || phone
      Current.account.contacts.create!(name: name, phone_number: phone)
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
      Rails.logger.warn "match_contacts: failed to create contact for #{phone}: #{e.message}"
      nil
    end
  end

  def parse_audience_param
    return [] if params[:audience].blank?

    permitted = params.permit(audience: [:type, :id, :key, :value, :name, :label, { contact_ids: [] }])[:audience] || []
    permitted.map { |item| item.to_h.with_indifferent_access }
  end

  def campaign
    @campaign ||= Current.account.campaigns.find_by!(display_id: params[:id])
  end

  def campaign_params
    params.require(:campaign).permit(
      :title, :description, :message, :enabled, :trigger_only_during_business_hours,
      :inbox_id, :sender_id, :scheduled_at,
      audience: [:type, :id, :key, :value, :name, :label, { contact_ids: [] }],
      trigger_rules: {}, template_params: {}
    )
  end

  def campaign_params_with_draft_status
    base = campaign_params
    inbox = Current.account.inboxes.find_by(id: base[:inbox_id])
    if inbox && ['Twilio SMS', 'Sms', 'Whatsapp'].include?(inbox.inbox_type)
      base.merge(campaign_status: :draft)
    else
      base
    end
  end
end
