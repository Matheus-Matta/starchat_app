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
    phones       = Array(params[:phones]).map(&:to_s).map(&:strip).reject(&:blank?)
    emails       = Array(params[:emails]).map(&:to_s).map(&:strip).reject(&:blank?)

    base = Current.account.contacts
    scopes = []
    scopes << base.where(id: ids)          if ids.any?
    scopes << base.where(identifier: identifiers) if identifiers.any?
    scopes << base.where(phone_number: phones)    if phones.any?
    scopes << base.where(email: emails)           if emails.any?

    contacts = scopes.reduce(Contact.none) { |acc, s| acc.or(s) }
    contacts = base.merge(contacts)

    input_count = (ids + identifiers + phones + emails).uniq.size

    render json: {
      contacts: contacts.map { |c| { id: c.id, name: c.name, email: c.email, phone_number: c.phone_number, identifier: c.identifier } },
      matched: contacts.count,
      unmatched: [input_count - contacts.count, 0].max
    }
  end

  private

  def parse_audience_param
    raw = params[:audience]
    return [] if raw.blank?

    array = raw.respond_to?(:values) ? raw.values : Array(raw)
    array.map do |item|
      h = item.respond_to?(:to_unsafe_h) ? item.to_unsafe_h : item.to_h
      h.with_indifferent_access
    end
  end

  def campaign
    @campaign ||= Current.account.campaigns.find_by!(display_id: params[:id])
  end

  def campaign_params
    params.require(:campaign).permit(
      :title, :description, :message, :enabled, :trigger_only_during_business_hours,
      :inbox_id, :sender_id, :scheduled_at,
      audience: [:type, :id, :key, :value, { contact_ids: [] }],
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
