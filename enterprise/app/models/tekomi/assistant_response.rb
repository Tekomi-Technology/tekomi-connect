# == Schema Information
#
# Table name: tekomi_assistant_responses
#
#  id                :bigint           not null, primary key
#  answer            :text             not null
#  documentable_type :string
#  edited            :boolean          default(FALSE), not null
#  question          :string           not null
#  status            :integer          default("approved"), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  account_id        :bigint           not null
#  assistant_id      :bigint           not null
#  documentable_id   :bigint
#
# Indexes
#
#  idx_cap_asst_resp_on_documentable                 (documentable_id,documentable_type)
#  index_tekomi_assistant_responses_on_account_id    (account_id)
#  index_tekomi_assistant_responses_on_assistant_id  (assistant_id)
#  index_tekomi_assistant_responses_on_status        (status)
#
class Tekomi::AssistantResponse < ApplicationRecord
  self.table_name = 'tekomi_assistant_responses'

  belongs_to :assistant, class_name: 'Tekomi::Assistant'
  belongs_to :account
  belongs_to :documentable, polymorphic: true, optional: true
  validates :question, presence: true
  validates :answer, presence: true
  validate :assistant_belongs_to_account

  before_validation :ensure_account
  before_validation :ensure_status
  before_validation :mark_as_edited, on: :update
  after_commit :sync_rag_document, on: %i[create update], if: :rag_indexable_changed?
  after_commit :delete_rag_document, on: :destroy

  scope :ordered, -> { order(created_at: :desc) }
  scope :by_account, ->(account_id) { where(account_id: account_id) }
  scope :by_assistant, ->(assistant_id) { where(assistant_id: assistant_id) }
  scope :with_document, ->(document_id) { where(document_id: document_id) }

  enum status: { approved: 1 }

  def customer_visible_source_url
    documentable.customer_visible_source_url if documentable.is_a?(Tekomi::Document)
  end

  private

  def ensure_status
    self.status ||= :approved
  end

  def mark_as_edited
    self.edited = true if question_changed? || answer_changed?
  end

  def ensure_account
    self.account ||= assistant&.account
  end

  def assistant_belongs_to_account
    return if assistant.blank? || assistant.account_id == account_id

    errors.add(:assistant, :invalid)
  end

  def sync_rag_document
    Tekomi::Rag::IndexJob.perform_later(record_type: 'assistant_response', record_id: id)
  end

  def rag_indexable_changed?
    previous_changes.keys.intersect?(%w[question answer status assistant_id account_id documentable_id documentable_type])
  end

  def delete_rag_document
    Tekomi::Rag::DeleteJob.perform_later(account_id: account_id, record_type: 'assistant_response', record_id: id)
  end
end
