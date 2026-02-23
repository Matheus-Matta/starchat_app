# frozen_string_literal: true

namespace :starchat do
  namespace :db do
    desc 'Sync default feature flags to all existing accounts'
    task sync_features: :environment do
      updated = Starchat::SyncDefaultAccountFeaturesService.new.perform
      puts "Done. #{updated} account(s) updated."
    end
  end
end
