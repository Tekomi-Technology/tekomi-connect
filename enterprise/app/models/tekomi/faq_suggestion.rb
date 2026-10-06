# == Schema Information
#
# Table name: tekomi_faq_suggestions
#
#  id           :bigint           not null, primary key
#  answer       :text             not null
#  language     :string           default("en"), not null
#  question     :string           not null
#  source_count :integer          default(0), not null
#  status       :integer          default("open"), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  account_id   :bigint           not null
#  assistant_id :bigint           not null
#
# Indexes
#
#  idx_cap_faq_suggestions_on_account_assistant_status_language  (account_id,assistant_id,status,language)
#  index_tekomi_faq_suggestions_on_account_id                    (account_id)
#  index_tekomi_faq_suggestions_on_assistant_id                  (assistant_id)
#
class Tekomi::FaqSuggestion < ApplicationRecord
  self.table_name = 'tekomi_faq_suggestions'

  belongs_to :assistant, class_name: 'Tekomi::Assistant'
  belongs_to :account
  has_many :observations,
           class_name: 'Tekomi::FaqObservation',
           dependent: :delete_all,
           inverse_of: :faq_suggestion
  enum status: { open: 0, approved: 1, dismissed: 2 }

  validates :question, :answer, :language, presence: true

  before_validation :ensure_account
  after_commit :sync_rag_document, on: %i[create update], if: :rag_indexable_changed?
  after_commit :delete_rag_document, on: :destroy

  scope :ordered, -> { order(source_count: :desc, updated_at: :desc) }
  scope :by_language, ->(language) { where(language: language) }

  private

  def ensure_account
    self.account = assistant&.account
  end

  def sync_rag_document
    Tekomi::Rag::IndexJob.perform_later(record_type: 'faq_suggestion', record_id: id)
  end

  def rag_indexable_changed?
    previous_changes.keys.intersect?(%w[question answer status language assistant_id account_id])
  end

  def delete_rag_document
    Tekomi::Rag::DeleteJob.perform_later(account_id: account_id, record_type: 'faq_suggestion', record_id: id)
  end
end
