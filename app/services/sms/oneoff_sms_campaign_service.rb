class Sms::OneoffSmsCampaignService
  include Campaigns::AudienceResolver
  pattr_initialize [:campaign!]

  def perform
    raise "Invalid campaign #{campaign.id}" if campaign.inbox.inbox_type != 'Sms' || !campaign.one_off?
    raise 'Completed Campaign' if campaign.completed?

    campaign.completed!
    process_audience(contacts_for_audience(campaign.account, campaign.audience))
  end

  private

  delegate :inbox, to: :campaign
  delegate :channel, to: :inbox

  def process_audience(contacts)
    contacts.each do |contact|
      next if contact.phone_number.blank?

      campaign_contact = campaign.campaign_contacts.find_or_create_by!(contact: contact)
      campaign_contact.update!(status: :pending)

      content = Liquid::CampaignTemplateService.new(campaign: campaign, contact: contact).call(campaign.message)

      begin
        channel.send_text_message(contact.phone_number, content)
        campaign_contact.update!(status: :sent, sent_at: Time.current)
      rescue StandardError => e
        Rails.logger.error("[SMS Campaign #{campaign.id}] Failed to send to #{contact.phone_number}: #{e.message}")
        campaign_contact.update!(status: :failed, error_message: e.message)
      end
    end
  end
end
