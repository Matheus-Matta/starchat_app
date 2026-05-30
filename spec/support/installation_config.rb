RSpec.configure do |config|
  config.before(:suite) do
    # Terminate stale connections left by previous aborted runs to prevent lock conflicts
    ActiveRecord::Base.connection.execute(<<~SQL)
      SELECT pg_terminate_backend(pid)
      FROM pg_stat_activity
      WHERE datname = current_database()
        AND state = 'idle in transaction'
        AND pid <> pg_backend_pid()
    SQL

    # Remove transactional test rows left by aborted before_all/let_it_be blocks from prior runs
    %w[contacts conversations messages contact_inboxes].each do |table|
      ActiveRecord::Base.connection.execute("DELETE FROM #{table}") rescue nil
    end

    ConfigLoader.new.process
    # Pre-generate VAPID keys so VapidService doesn't INSERT during tests
    InstallationConfig.find_by(name: 'VAPID_KEYS') || VapidService.send(:vapid_keys)
    GlobalConfig.clear_cache
  end
end
