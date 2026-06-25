# TODO: logic is written tailored to contact import since its the only import available
# let's break this logic and clean this up in future

class DataImportJob < ApplicationJob
  queue_as :low
  retry_on ActiveStorage::FileNotFoundError, wait: 1.minute, attempts: 3

  LABELS_DELIMITER = ','.freeze
  LABELS_CONTEXT = 'labels'.freeze
  CONTACT_TAGGABLE_TYPE = 'Contact'.freeze
  INBOXES_DELIMITER = ','.freeze

  def perform(data_import)
    @data_import = data_import
    @contact_manager = DataImport::ContactManager.new(@data_import.account)
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
    contacts, rejected_contacts = parse_csv_and_build_contacts

    import_contacts(contacts)
    update_data_import_status(contacts.length, rejected_contacts.length)
    save_failed_records_csv(rejected_contacts)
  end

  def parse_csv_and_build_contacts
    contacts = []
    rejected_contacts = []

    each_import_row do |row|
      build_contact_from_row(row, contacts, rejected_contacts)
    end

    [contacts, rejected_contacts]
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

  def build_contact_from_row(row, contacts, rejected_contacts)
    row_hash = row.to_h.with_indifferent_access
    labels = extract_labels(row_hash)
    inbox_names = extract_inbox_names(row_hash)

    errors = label_and_inbox_errors(labels, inbox_names)
    if errors.present?
      append_row_error(row, errors, rejected_contacts)
      return
    end

    current_contact = @contact_manager.build_contact(row_hash.except(:labels, :inboxes))
    if current_contact.valid?
      contacts << { contact: current_contact, labels: labels, inbox_names: inbox_names }
    else
      append_rejected_contact(row, current_contact, rejected_contacts)
    end
  end

  def label_and_inbox_errors(labels, inbox_names)
    errors = []
    invalid_labels = labels.map(&:downcase) - approved_labels
    errors << "Unknown labels: #{invalid_labels.join(', ')}" if invalid_labels.present?

    invalid_inboxes = inbox_names.reject { |name| inboxes_by_downcased_name.key?(name.downcase) }
    errors << "Unknown inboxes: #{invalid_inboxes.join(', ')}" if invalid_inboxes.present?

    errors
  end

  def extract_labels(row_hash)
    row_hash[:labels].to_s.split(LABELS_DELIMITER).map(&:strip).reject(&:blank?)
  end

  def extract_inbox_names(row_hash)
    row_hash[:inboxes].to_s.split(INBOXES_DELIMITER).map(&:strip).reject(&:blank?)
  end

  def append_rejected_contact(row, contact, rejected_contacts)
    row['errors'] = contact.errors.full_messages.join(', ')
    rejected_contacts << row
  end

  def import_contacts(contacts_with_labels)
    contacts = contacts_with_labels.pluck(:contact)
    # <struct ActiveRecord::Import::Result failed_instances=[], num_inserts=1, ids=[444, 445], results=[]>
    Contact.import(contacts, synchronize: contacts, on_duplicate_key_ignore: true, track_validation_failures: true, validate: true, batch_size: 1000)
    apply_labels_to_contacts(contacts_with_labels)
    apply_inboxes_to_contacts(contacts_with_labels)
  end

  def apply_labels_to_contacts(contacts_with_labels)
    taggings = taggings_for_contacts(contacts_with_labels)
    return if taggings.blank?

    ActsAsTaggableOn::Tagging.import(%i[tag_id taggable_type taggable_id context created_at],
                                     taggings, on_duplicate_key_ignore: true, validate: false, batch_size: 1000)
  end

  def taggings_for_contacts(contacts_with_labels)
    tag_lookup = tags_by_label_name(contacts_with_labels)
    taggings = contacts_with_labels.flat_map do |item|
      contact = persisted_contact_for(item[:contact])
      labels = item[:labels].map(&:downcase).uniq
      next [] if contact&.id.blank?

      labels.map do |label|
        [tag_lookup[label].id, CONTACT_TAGGABLE_TYPE, contact.id, LABELS_CONTEXT]
      end
    end.uniq

    reject_existing_taggings(taggings).map { |tagging| tagging + [Time.zone.now] }
  end

  def reject_existing_taggings(taggings)
    tag_ids = taggings.map { |tag_id, _taggable_type, _taggable_id, _context| tag_id }
    taggable_ids = taggings.map { |_tag_id, _taggable_type, taggable_id, _context| taggable_id }
    existing_taggings = ActsAsTaggableOn::Tagging
                        .where(context: LABELS_CONTEXT, taggable_type: CONTACT_TAGGABLE_TYPE,
                               taggable_id: taggable_ids, tag_id: tag_ids)
                        .pluck(:tag_id, :taggable_id)
                        .index_with(true)

    taggings.reject do |tag_id, _taggable_type, taggable_id, _context|
      existing_taggings[[tag_id, taggable_id]]
    end
  end

  def persisted_contact_for(contact)
    return contact if contact.id.present?

    key = contact_identity_key(contact)
    return if key.blank?

    imported_contact(contact)
  end

  def contact_identity_key(contact)
    contact.identifier.presence || contact.email.presence || contact.phone_number.presence
  end

  def imported_contact(contact)
    return @data_import.account.contacts.find_by(identifier: contact.identifier) if contact.identifier.present?
    return @data_import.account.contacts.from_email(contact.email) if contact.email.present?

    @data_import.account.contacts.find_by(phone_number: contact.phone_number) if contact.phone_number.present?
  end

  def tags_by_label_name(contacts_with_labels)
    labels = contacts_with_labels.flat_map { |item| item[:labels] }.map(&:downcase).uniq

    ActsAsTaggableOn::Tag.find_or_create_all_with_like_by_name(labels).index_by { |tag| tag.name.downcase }
  end

  def approved_labels
    @approved_labels ||= @data_import.account.labels.pluck(:title)
  end

  def inboxes_by_downcased_name
    @inboxes_by_downcased_name ||= @data_import.account.inboxes.index_by { |inbox| inbox.name.downcase }
  end

  def append_row_error(row, errors, rejected_contacts)
    row['errors'] = errors.join('; ')
    rejected_contacts << row
  end

  # Links contacts to the inboxes named in their "inboxes" column. Unlike labels, this can't be
  # bulk-imported: each channel type generates its own source_id (e.g. WhatsApp needs the contact's
  # phone), so we go through ContactInboxBuilder per (contact, inbox) pair and skip links it can't
  # build (e.g. missing phone/email, or a channel that requires an external source_id) instead of
  # failing the whole row.
  def apply_inboxes_to_contacts(contacts_with_labels)
    contacts_with_labels.each do |item|
      next if item[:inbox_names].blank?

      contact = persisted_contact_for(item[:contact])
      next if contact&.id.blank?

      item[:inbox_names].uniq.each { |name| link_contact_to_inbox(contact, name) }
    end
  end

  def link_contact_to_inbox(contact, inbox_name)
    inbox = inboxes_by_downcased_name[inbox_name.downcase]
    return unless inbox

    ContactInboxBuilder.new(contact: contact, inbox: inbox).perform
  rescue ActionController::ParameterMissing, RuntimeError => e
    Rails.logger.info("[DataImportJob] Could not link contact #{contact.id} to inbox #{inbox.id}: #{e.message}")
  end

  def update_data_import_status(processed_records, rejected_records)
    @data_import.update!(status: :completed, processed_records: processed_records, total_records: processed_records + rejected_records)
  end

  def save_failed_records_csv(rejected_contacts)
    csv_data = generate_csv_data(rejected_contacts)
    return if csv_data.blank?

    @data_import.failed_records.attach(io: StringIO.new(csv_data), filename: "#{Time.zone.today.strftime('%Y%m%d')}_contacts.csv",
                                       content_type: 'text/csv')
  end

  def generate_csv_data(rejected_contacts)
    headers = csv_headers
    headers << 'errors'
    return if rejected_contacts.blank?

    CSV.generate do |csv|
      csv << headers
      rejected_contacts.each do |record|
        csv << record
      end
    end
  end

  def handle_csv_error(error)
    @data_import.update!(status: :failed)
    send_import_failed_notification_to_admin
  end

  def send_import_notification_to_admin
    AdministratorNotifications::AccountNotificationMailer.with(account: @data_import.account).contact_import_complete(@data_import).deliver_later
  end

  def send_import_failed_notification_to_admin
    AdministratorNotifications::AccountNotificationMailer.with(account: @data_import.account).contact_import_failed.deliver_later
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
