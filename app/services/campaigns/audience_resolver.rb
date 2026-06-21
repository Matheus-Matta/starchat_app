module Campaigns
  module AudienceResolver
    def contacts_for_audience(account, audience)
      contact_ids = Set.new

      label_ids = audience.filter_map { |a| a['id'].to_i if a['type'] == 'Label' }.reject(&:zero?)
      if label_ids.any?
        labels = account.labels.where(id: label_ids).pluck(:title)
        contact_ids.merge(account.contacts.tagged_with(labels, any: true).pluck(:id)) if labels.any?
      end

      company_ids = audience.filter_map { |a| a['id'].to_i if a['type'] == 'Company' }.reject(&:zero?)
      contact_ids.merge(account.contacts.where(company_id: company_ids).pluck(:id)) if company_ids.any?

      audience.select { |a| a['type'] == 'ContactList' }.each do |item|
        ids = Array(item['contact_ids']).map(&:to_i).reject(&:zero?)
        contact_ids.merge(ids)
      end

      audience.select { |a| a['type'] == 'Attribute' }.each do |item|
        key = item['key'].to_s.strip
        value = item['value'].to_s.strip
        next if key.blank? || value.blank?

        contact_ids.merge(
          account.contacts.where("custom_attributes->>? = ?", key, value).pluck(:id)
        )
      end

      contact_ids.empty? ? Contact.none : account.contacts.where(id: contact_ids.to_a)
    end
  end
end
