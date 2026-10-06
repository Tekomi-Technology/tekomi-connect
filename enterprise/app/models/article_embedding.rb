# == Schema Information
#
# Table name: article_embeddings
#
#  id         :bigint           not null, primary key
#  term       :text             not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  article_id :bigint           not null
#
# Indexes
#
#
class ArticleEmbedding < ApplicationRecord
  belongs_to :article
  after_commit :sync_rag_document, on: %i[create update], if: :rag_indexable_changed?
  after_commit :delete_rag_document, on: :destroy

  delegate :account_id, to: :article

  private

  def sync_rag_document
    Tekomi::Rag::IndexJob.perform_later(record_type: 'article_embedding', record_id: id)
  end

  def rag_indexable_changed?
    previous_changes.keys.intersect?(%w[term article_id])
  end

  def delete_rag_document
    Tekomi::Rag::DeleteJob.perform_later(account_id: account_id, record_type: 'article_embedding', record_id: id)
  end
end
