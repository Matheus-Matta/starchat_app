class BackfillFeatureContactAttributesForAssistants < ActiveRecord::Migration[7.1]
  # Only backfill assistants on accounts with cosmos_integration_v2 enabled.
  # V1 assistants never had contact attributes, so limit to v2.
  def up
    return unless StarchatsApp.enterprise?

    Account.feature_cosmos_integration_v2.find_each do |account|
      account.cosmos_assistants.each do |assistant|
        next if assistant.feature_contact_attributes.present?

        assistant.update(feature_contact_attributes: true)
      end
    end
  end

  def down
    return unless StarchatsApp.enterprise?

    Account.feature_cosmos_integration_v2.find_each do |account|
      account.cosmos_assistants.each do |assistant|
        next if assistant.feature_contact_attributes.blank?

        assistant.update(feature_contact_attributes: nil)
      end
    end
  end
end
