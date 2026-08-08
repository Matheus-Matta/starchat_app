require 'rails_helper'

RSpec.describe Internal::TriggerDailyScheduledItemsJob do
  before do
    allow(Cosmos::Documents::ScheduleSyncsJob).to receive(:perform_later)
  end

  it 'enqueues Cosmos document auto-sync for every account, on any day' do
    travel_to Time.zone.parse('2026-05-26 00:00:00 UTC') do
      described_class.perform_now
    end

    expect(Cosmos::Documents::ScheduleSyncsJob).to have_received(:perform_later).with(no_args)
  end

  it 'enqueues it on the same cadence regardless of the day of the week or month' do
    ['2026-05-24 00:00:00 UTC', '2026-05-25 00:00:00 UTC', '2026-06-01 00:00:00 UTC'].each do |timestamp|
      travel_to(Time.zone.parse(timestamp)) { described_class.perform_now }
    end

    expect(Cosmos::Documents::ScheduleSyncsJob).to have_received(:perform_later).with(no_args).exactly(3).times
  end
end
