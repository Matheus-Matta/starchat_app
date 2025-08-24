require 'rails_helper'

RSpec.describe Starchat::CreateStripeCustomerJob, type: :job do
  include ActiveJob::TestHelper
  subject(:job) { described_class.perform_later(account) }

  let(:account) { create(:account) }

  it 'queues the job' do
    expect { job }.to have_enqueued_job(described_class)
      .with(account)
      .on_queue('default')
  end
end
