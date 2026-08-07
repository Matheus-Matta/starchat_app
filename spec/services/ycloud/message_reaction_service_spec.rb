require 'rails_helper'

RSpec.describe Ycloud::MessageReactionService do
  let(:account) do
    create(:account).tap { |record| record.enable_features!(:channel_ycloud) }
  end
  let(:channel) do
    create(
      :channel_whatsapp,
      account: account,
      provider: 'ycloud',
      provider_config: {
        'api_key' => 'key',
        'waba_id' => 'waba',
        'phone_number_id' => 'phone',
        'webhook_secret' => 'secret'
      },
      sync_templates: false,
      validate_provider_config: false
    )
  end
  let(:conversation) { create(:conversation, inbox: channel.inbox) }
  let!(:parent) do
    create(
      :message,
      conversation: conversation,
      inbox: channel.inbox,
      message_type: :outgoing,
      source_id: 'yc-parent',
      additional_attributes: {
        'ycloud_wamid_values' => ['wamid.parent']
      }
    )
  end

  it 'creates an incoming reply attached to the reacted message' do
    described_class.new(
      channel: channel,
      payload: {
        'id' => 'yc-reaction',
        'reaction' => { 'message_id' => 'wamid.parent', 'emoji' => '👍' }
      }
    ).perform

    reaction = conversation.messages.find_by(source_id: 'yc-reaction')
    expect(reaction.content).to eq('👍')
    expect(reaction.in_reply_to).to eq(parent.id)
    expect(reaction).to be_incoming
  end

  it 'removes the previous reaction when YCloud sends an empty emoji' do
    service = described_class.new(
      channel: channel,
      payload: {
        'id' => 'yc-reaction',
        'from' => '+5511999999999',
        'reaction' => { 'message_id' => 'wamid.parent', 'emoji' => '👍' }
      }
    )
    service.perform

    expect do
      described_class.new(
        channel: channel,
        payload: {
          'id' => 'yc-reaction',
          'from' => '+5511999999999',
          'reaction' => { 'message_id' => 'wamid.parent', 'emoji' => '' }
        }
      ).perform
    end.to change { conversation.messages.where(source_id: 'yc-reaction').count }.from(1).to(0)
  end

  it 'reports when the reacted message is not available yet' do
    result = described_class.new(
      channel: channel,
      payload: {
        'id' => 'yc-reaction',
        'reaction' => { 'message_id' => 'wamid.missing', 'emoji' => '👍' }
      }
    ).perform

    expect(result).to eq(:parent_not_found)
  end
end
