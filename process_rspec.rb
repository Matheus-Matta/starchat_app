pid = 91523

# Wait for process to finish
begin
  while Process.kill(0, pid)
    sleep 10
  end
rescue Errno::ESRCH
  # Process finished
end

# Process results
require 'json'

begin
  data = JSON.parse(File.read('log/rspec_results.json'))
  failures = data['examples'].select { |ex| ex['status'] == 'failed' }
  
  # Format the failures log nicely
  File.open('log/rspec_failures.log', 'w') do |f|
    f.puts "Total Failures: #{failures.size}\n\n"
    failures.each_with_index do |ex, i|
      f.puts "--- Failure #{i + 1} ---"
      f.puts "Description: #{ex['full_description']}"
      f.puts "Location: #{ex['file_path']}:#{ex['line_number']}"
      f.puts "Error: #{ex.dig('exception', 'class')}"
      f.puts "Message:\n#{ex.dig('exception', 'message')}"
      f.puts "-" * 40
      f.puts "\n"
    end
  end

  # The user also asked to "divide the logs of failures"
  # Let's create a directory and put individual files for each failure, or just group them by file?
  # Grouping by file seems more useful.
  grouped_failures = failures.group_by { |ex| ex['file_path'] }
  Dir.mkdir('log/rspec_failures_split') unless Dir.exist?('log/rspec_failures_split')
  
  grouped_failures.each do |file_path, file_failures|
    safe_name = file_path.gsub('/', '_').gsub('.rb', '.log')
    File.open("log/rspec_failures_split/#{safe_name}", 'w') do |f|
      f.puts "Failures for #{file_path}:\n\n"
      file_failures.each_with_index do |ex, i|
        f.puts "--- Failure #{i + 1} ---"
        f.puts "Description: #{ex['full_description']}"
        f.puts "Line: #{ex['line_number']}"
        f.puts "Message:\n#{ex.dig('exception', 'message')}"
        f.puts "-" * 40
        f.puts "\n"
      end
    end
  end
rescue => e
  File.open('log/rspec_failures.log', 'w') { |f| f.puts "Error processing JSON: #{e.message}" }
end
