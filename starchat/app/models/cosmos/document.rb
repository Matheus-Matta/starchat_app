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

  belongs_to :assistant, class_name: 'Cosmos::Assistant'
  has_many :responses, class_name: 'Cosmos::AssistantResponse', dependent: :destroy, as: :documentable
  belongs_to :account

  has_one_attached :pdf_file

  validates :external_link, presence: true
  validates :external_link, uniqueness: { scope: :assistant_id }
  validates :content, length: { maximum: 200_000 }
  
  before_validation :ensure_account_id
  before_validation :set_external_link_for_pdf
  before_validation :normalize_external_link

  enum status: {
    in_progress: 0,
    available: 1
  }

  before_create :ensure_within_plan_limit
  after_create_commit :enqueue_crawl_job
  after_create_commit :update_document_usage
  after_destroy :update_document_usage
  after_commit :enqueue_response_builder_job, on: [:create, :update]
  scope :ordered, -> { order(created_at: :desc) }

  scope :for_account, ->(account_id) { where(account_id: account_id) }
  scope :for_assistant, ->(assistant_id) { where(assistant_id: assistant_id) }

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

  def pdf_document?
    pdf_file.attached? || external_link&.to_s&.downcase&.end_with?('.pdf')
  end

  def store_openai_file_id(file_id)
    metadata['openai_file_id'] = file_id
    save!
  end

  def openai_file_id
    metadata['openai_file_id']
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
    return false if content.blank?

    # Enqueue if status changed to available OR content changed while available
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

  def validate_pdf_format
    return unless pdf_file.attached?

    errors.add(:pdf_file, I18n.t('cosmos.documents.pdf_format_error')) unless pdf_file.blob.content_type == 'application/pdf'
  end

  def validate_file_attachment
    return unless pdf_file.attached?

    return unless pdf_file.blob.byte_size > 10.megabytes

    errors.add(:pdf_file, I18n.t('cosmos.documents.pdf_size_error'))
  end

  def set_external_link_for_pdf
    return unless pdf_file.attached? && external_link.blank?

    # Set a unique external_link for PDF files
    # Format: PDF: filename_timestamp (without extension)
    timestamp = Time.current.strftime('%Y%m%d%H%M%S')
    self.external_link = "PDF: #{pdf_file.filename.base}_#{timestamp}"
  end
end
