class FixCompaniesContactsCount < ActiveRecord::Migration[7.1]
  def up
    # Initialize NULL contacts_count to 0 so counter cache works correctly
    execute <<~SQL
      UPDATE companies SET contacts_count = 0 WHERE contacts_count IS NULL
    SQL

    # Set column default to 0 so new companies start with correct count
    change_column_default :companies, :contacts_count, from: nil, to: 0

    # Reset counter cache for all companies using accurate contact counts
    Company.find_in_batches(batch_size: 100) do |batch|
      batch.each do |company|
        Company.reset_counters(company.id, :contacts)
      rescue StandardError => e
        Rails.logger.error "FixCompaniesContactsCount: company #{company.id} - #{e.message}"
      end
    end
  end

  def down
    change_column_default :companies, :contacts_count, from: 0, to: nil
  end
end
