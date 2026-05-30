FactoryBot.define do
  factory :installation_config do
    name { 'xyc' }
    value { 1.5 }
    locked { true }

    to_create do |instance|
      record = InstallationConfig.find_by(name: instance.name)
      if record
        record.update!(value: instance.value, locked: instance.locked)
        instance.id = record.id
        instance.reload
      else
        instance.save!
      end
    end
  end
end
