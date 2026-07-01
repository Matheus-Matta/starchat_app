class Whatsapp::OneoffCampaignService
  include Campaigns::AudienceResolver
  pattr_initialize [:campaign!]

  def perform
    validate_campaign!
    campaign.completed!
    process_audience(extract_audience_contacts)
  end

  private

  delegate :inbox, to: :campaign
  delegate :channel, to: :inbox

  def validate_campaign_type!
    raise "Invalid campaign #{campaign.id}" unless whatsapp_campaign? && campaign.one_off?
  end

  def whatsapp_campaign?
    campaign.inbox.inbox_type == 'Whatsapp'
  end

  def validate_campaign_status!
    raise 'Completed Campaign' if campaign.completed?
  end

  def validate_provider!
    raise 'WhatsApp Cloud provider required' if channel.provider != 'whatsapp_cloud'
  end

  def validate_feature_flag!
    raise 'WhatsApp campaigns feature not enabled' unless campaign.account.feature_enabled?(:whatsapp_campaign)
  end

  def validate_campaign!
    validate_campaign_type!
    validate_campaign_status!
    validate_provider!
    validate_feature_flag!
  end

  def extract_audience_contacts
    contacts_for_audience(campaign.account, campaign.audience)
  end

  def process_contact(contact, campaign_contact)
    Rails.logger.info "Processing contact: #{contact.name} (#{contact.phone_number})"

    if contact.phone_number.blank?
      Rails.logger.info "Skipping contact #{contact.name} - no phone number"
      campaign_contact.update!(status: :failed, error_message: 'No phone number')
      return
    end

    if campaign.template_params.blank?
      if campaign.message.present?
        send_plain_text_message(to: contact.phone_number, text: campaign.message, campaign_contact: campaign_contact)
      else
        msg = 'No template_params or message found for WhatsApp campaign'
        Rails.logger.error "Skipping contact #{contact.name} - #{msg}"
        campaign_contact.update!(status: :failed, error_message: msg)
      end
      return
    end

    processed_template_params = process_liquid_template_params(contact)
    if processed_template_params.nil?
      campaign_contact.update!(status: :failed, error_message: 'Liquid variables resolved to blank values')
      return
    end

    send_whatsapp_template_message(to: contact.phone_number, template_params: processed_template_params,
                                   campaign_contact: campaign_contact)
  end

  def process_audience(contacts)
    Rails.logger.info "Processing #{contacts.count} contacts for campaign #{campaign.id}"

    contacts.each do |contact|
      campaign_contact = campaign.campaign_contacts.find_or_create_by!(contact: contact)
      campaign_contact.update!(status: :pending)
      process_contact(contact, campaign_contact)
    end

    Rails.logger.info "Campaign #{campaign.id} processing completed"
  end

  def process_liquid_template_params(contact)
    liquid_processor = Whatsapp::LiquidTemplateProcessorService.new(campaign: campaign, contact: contact)
    processed_template_params = liquid_processor.process_template_params(campaign.template_params)

    Rails.logger.info "Skipping contact #{contact.name} - liquid variables resolved to blank values" if processed_template_params.nil?

    processed_template_params
  rescue StandardError => e
    Rails.logger.error "Failed to process liquid template params for contact #{contact.name}: #{e.message}"
    nil
  end

  def send_plain_text_message(to:, text:, campaign_contact:)
    success = channel.provider_service.send_plain_text(to, text)
    if success
      campaign_contact.update!(status: :sent, sent_at: Time.current)
    else
      campaign_contact.update!(status: :failed, error_message: 'WhatsApp API rejected plain text message')
    end
  rescue StandardError => e
    Rails.logger.error "Failed to send plain text WhatsApp message to #{to}: #{e.message}"
    campaign_contact.update!(status: :failed, error_message: e.message)
  end

  def send_whatsapp_template_message(to:, template_params:, campaign_contact:)
    processor = Whatsapp::TemplateProcessorService.new(channel: channel, template_params: template_params)
    name, namespace, lang_code, processed_parameters = processor.call

    return if name.blank?

    source_id = channel.send_template(to, { name: name, namespace: namespace, lang_code: lang_code, parameters: processed_parameters }, nil)
    campaign_contact.update!(status: :sent, sent_at: Time.current)

    register_campaign_message(campaign_contact.contact, source_id, template_params)
  rescue StandardError => e
    Rails.logger.error "Failed to send WhatsApp template message to #{to}: #{e.message}"
    Rails.logger.error "Backtrace: #{e.backtrace.first(5).join('\n')}"
    campaign_contact.update!(status: :failed, error_message: e.message)
    nil
  end

  def find_or_open_conversation(contact)
    wa_source_id = contact.phone_number.to_s.delete('+')
    contact_inbox = contact.contact_inboxes.find_or_create_by!(inbox: inbox) do |ci|
      ci.source_id = wa_source_id
    end

    existing = if inbox.lock_to_single_conversation?
                 contact_inbox.conversations.last
               else
                 contact_inbox.conversations.where.not(status: :resolved).last
               end

    return existing if existing

    contact_inbox.conversations.create!(
      account: campaign.account,
      inbox: inbox,
      contact: contact,
      status: :open,
      additional_attributes: { campaign_id: campaign.display_id }
    )
  end

  def register_campaign_message(contact, source_id, template_params)
    conversation = find_or_open_conversation(contact)
    return unless conversation

    Messages::MessageBuilder.new(
      campaign.sender,
      conversation,
      {
        message_type: 'template',
        content: campaign.message,
        template_params: template_params,
        source_id: source_id,
        campaign_id: campaign.display_id,
        skip_external_send: true
      }
    ).perform
  rescue StandardError => e
    Rails.logger.error "Failed to register campaign message for contact #{contact.name}: #{e.message}"
  end
end
