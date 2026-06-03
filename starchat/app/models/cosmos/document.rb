# == Schema Information
#
# Table name: cosmos_documents
#
#  id            :bigint           not null, primary key
#  content       :text
#  external_link :string           not null
#  metadata      :jsonb
#  name          :string
#  status        :integer          default("in_progress"), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  account_id    :bigint           not null
#  assistant_id  :bigint           not null
#
# Indexes
#
#  index_cosmos_documents_on_account_id                      (account_id)
#  index_cosmos_documents_on_assistant_id                    (assistant_id)
#  index_cosmos_documents_on_assistant_id_and_external_link  (assistant_id,external_link) UNIQUE
#  index_cosmos_documents_on_status                          (status)
#
class Cosmos::Document < ApplicationRecord
  class LimitExceededError < StandardError; end
  self.table_name = 'cosmos_documents'
  SYNC_STALE_TIMEOUT = 2.hours

  belongs_to :assistant, class_name: 'Cosmos::Assistant'
  has_many :responses, class_name: 'Cosmos::AssistantResponse', dependent: :destroy, as: :documentable
  belongs_to :account

  # Handles PDF, XLSX, CSV, etc. Named 'pdf_file' for legacy reasons.
  has_one_attached :pdf_file

  validates :external_link, presence: true
  validates :external_link, uniqueness: { scope: :assistant_id }
  validates :content, length: { maximum: 200_000 }

  before_validation :ensure_account_id
  before_validation :set_external_link_for_file
  before_validation :normalize_external_link

  validate :validate_file_format
  validate :validate_file_attachment

  enum status: {
    in_progress: 0,
    available: 1
  }

  enum :sync_status, { syncing: 0, synced: 1, failed: 2 }, prefix: :sync

  before_create :ensure_within_plan_limit
  after_create_commit :enqueue_crawl_job
  after_create_commit :update_document_usage
  after_destroy :update_document_usage
  after_commit :enqueue_response_builder_job, on: [:create, :update]

  scope :ordered,       -> { order(created_at: :desc) }
  scope :for_account,   ->(account_id)   { where(account_id: account_id) }
  scope :for_assistant, ->(assistant_id) { where(assistant_id: assistant_id) }
  scope :syncable,      -> { where("external_link NOT LIKE 'PDF:%' AND external_link NOT LIKE '%.pdf'") }
  scope :pdf_documents, -> { where("external_link LIKE 'PDF:%' OR external_link LIKE '%.pdf'") }
  scope :sync_in_progress, -> { sync_syncing.where(arel_table[:last_sync_attempted_at].gteq(SYNC_STALE_TIMEOUT.ago)) }
  scope :stale, lambda { |stale_before|
    sync_failed.or(sync_synced.where(arel_table[:last_synced_at].lt(stale_before)))
  }
  scope :synced_since, lambda { |time|
    sync_synced.where(arel_table[:last_synced_at].gteq(time))
  }

  def content_type
    return pdf_file.blob.content_type if pdf_file.attached?

    'text/html'
  end

  def display_url
    return external_link unless pdf_file.attached?

    external_link.presence || pdf_file.filename.to_s
  end

  def file_size
    return pdf_file.blob.byte_size if pdf_file.attached?

    nil
  end

  def file_document?
    return true if pdf_file.attached?

    link = external_link.to_s
    link.start_with?('PDF:') || link.downcase.match?(/\.(pdf|xlsx?|csv)\z/)
  end

  # Deprecated alias
  alias pdf_document? file_document?

  def syncable?
    !file_document?
  end

  def sync_stale?
    sync_syncing? && (last_sync_attempted_at.blank? || last_sync_attempted_at < SYNC_STALE_TIMEOUT.ago)
  end

  def sync_in_progress?
    sync_syncing? && !sync_stale?
  end

  def to_llm_metadata
    { document_id: id, assistant_id: assistant_id, external_link: external_link }
  end

  def store_openai_file_id(file_id)
    metadata['openai_file_id'] = file_id
    save!
  end

  def openai_file_id
    metadata['openai_file_id']
  end

  def last_sync_error_code
    metadata['last_sync_error_code']
  end

  private

  def normalize_external_link
    self.external_link = external_link&.chomp('/') if external_link.present?
  end

  def enqueue_crawl_job
    return if status != 'in_progress'

    Cosmos::Documents::CrawlJob.perform_later(self)
  end

  def enqueue_response_builder_job
    return unless should_enqueue_response_builder?

    Cosmos::Documents::ResponseBuilderJob.perform_later(self)
  end

  def should_enqueue_response_builder?
    return false unless status == 'available'
    return false if content.blank? && openai_file_id.blank?

    # Enqueue if status changed to available OR content/file_id changed while available
    saved_change_to_status? || saved_change_to_content?
  end

  def update_document_usage
    account.update_document_usage
  end

  def ensure_account_id
    self.account_id = assistant&.account_id
  end

  def ensure_within_plan_limit
    limits = account.usage_limits[:cosmos][:documents]
    raise LimitExceededError, I18n.t('cosmos.documents.limit_exceeded') unless limits[:current_available].positive?
  end

  def validate_file_format
    return unless pdf_file.attached?

    allowed_types = %w[
      application/pdf
      application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
      application/vnd.ms-excel
      text/csv
    ]

    return if allowed_types.include?(pdf_file.blob.content_type)

    errors.add(:pdf_file, I18n.t('cosmos.documents.file_format_error'))
  end

  def validate_file_attachment
    return unless pdf_file.attached?

    return unless pdf_file.blob.byte_size > 10.megabytes

    errors.add(:pdf_file, I18n.t('cosmos.documents.file_size_error'))
  end

  def set_external_link_for_file
    return unless pdf_file.attached? && external_link.blank?

    timestamp = Time.current.strftime('%Y%m%d%H%M%S')
    self.external_link = "PDF: #{pdf_file.filename.base}_#{timestamp}"
  end
end
