class CompaniesDataImportJob < ApplicationJob
  queue_as :low
  retry_on ActiveStorage::FileNotFoundError, wait: 1.minute, attempts: 3

  def perform(data_import)
    @data_import = data_import
    @company_manager = DataImport::CompanyManager.new(@data_import.account)
    begin
      process_import_file
      send_import_notification_to_admin
    rescue CSV::MalformedCSVError, Roo::Error => e
      handle_csv_error(e)
    end
  end

  private

  def process_import_file
    @data_import.update!(status: :processing)
    companies, rejected_companies = parse_csv_and_build_companies

    import_companies(companies)
    update_data_import_status(companies.length, rejected_companies.length)
    save_failed_records_csv(rejected_companies)
  end

  def parse_csv_and_build_companies
    companies = []
    rejected_companies = []

    each_import_row do |row|
      build_company_from_row(row, companies, rejected_companies)
    end

    [companies, rejected_companies]
  end

  def each_import_row(&block)
    if spreadsheet_file?
      each_spreadsheet_row(&block)
    else
      with_import_file do |file|
        csv_reader(file).each(&block)
      end
    end
  end

  def spreadsheet_file?
    @data_import.import_file.filename.to_s.downcase.match?(/\.(xls|xlsx)\z/)
  end

  def each_spreadsheet_row
    with_import_file do |file|
      ext = File.extname(@data_import.import_file.filename.to_s).delete_prefix('.').to_sym
      spreadsheet = Roo::Spreadsheet.open(file.path, extension: ext)
      headers = spreadsheet.row(1).map { |h| h.to_s.strip }
      (2..spreadsheet.last_row).each do |i|
        values = spreadsheet.row(i).map { |v| v.nil? ? nil : v.to_s }
        yield CSV::Row.new(headers, values)
      end
    end
  end

  def build_company_from_row(row, companies, rejected_companies)
    row_hash = row.to_h.with_indifferent_access
    current_company = @company_manager.build_company(row_hash)
    if current_company.valid?
      companies << current_company
    else
      append_rejected_company(row, current_company, rejected_companies)
    end
  end

  def append_rejected_company(row, company, rejected_companies)
    row['errors'] = company.errors.full_messages.join(', ')
    rejected_companies << row
  end

  def import_companies(companies)
    Company.import(companies, synchronize: companies, on_duplicate_key_ignore: true, track_validation_failures: true, validate: true, batch_size: 1000)
  end

  def update_data_import_status(processed_records, rejected_records)
    @data_import.update!(status: :completed, processed_records: processed_records, total_records: processed_records + rejected_records)
  end

  def save_failed_records_csv(rejected_companies)
    csv_data = generate_csv_data(rejected_companies)
    return if csv_data.blank?

    @data_import.failed_records.attach(io: StringIO.new(csv_data), filename: "#{Time.zone.today.strftime('%Y%m%d')}_companies.csv",
                                       content_type: 'text/csv')
  end

  def generate_csv_data(rejected_companies)
    headers = csv_headers
    headers << 'errors'
    return if rejected_companies.blank?

    CSV.generate do |csv|
      csv << headers
      rejected_companies.each { |record| csv << record }
    end
  end

  def handle_csv_error(error)
    @data_import.update!(status: :failed)
    send_import_failed_notification_to_admin
  end

  def send_import_notification_to_admin
    AdministratorNotifications::AccountNotificationMailer.with(account: @data_import.account).company_import_complete(@data_import).deliver_later
  end

  def send_import_failed_notification_to_admin
    AdministratorNotifications::AccountNotificationMailer.with(account: @data_import.account).company_import_failed.deliver_later
  end

  def csv_headers
    if spreadsheet_file?
      with_import_file do |file|
        ext = File.extname(@data_import.import_file.filename.to_s).delete_prefix('.').to_sym
        spreadsheet = Roo::Spreadsheet.open(file.path, extension: ext)
        return spreadsheet.row(1).map { |h| h.to_s.strip }
      end
    end

    header_row = nil
    with_import_file do |file|
      header_row = csv_reader(file).first
    end
    header_row&.headers || []
  end

  def csv_reader(file)
    file.rewind
    raw_data = file.read
    utf8_data = raw_data.force_encoding('UTF-8')
    clean_data = utf8_data.valid_encoding? ? utf8_data : utf8_data.encode('UTF-16le', invalid: :replace, replace: '').encode('UTF-8')
    clean_data = clean_data.delete_prefix("\xEF\xBB\xBF")

    CSV.new(StringIO.new(clean_data), headers: true)
  end

  def with_import_file
    temp_dir = Rails.root.join('tmp/imports')
    FileUtils.mkdir_p(temp_dir)

    @data_import.import_file.open(tmpdir: temp_dir) do |file|
      file.binmode
      yield file
    end
  end
end
