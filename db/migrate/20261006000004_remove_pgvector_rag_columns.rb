class RemovePgvectorRagColumns < ActiveRecord::Migration[7.2]
  def up
    remove_index :tekomi_assistant_responses, name: 'vector_idx_knowledge_entries_embedding', if_exists: true
    remove_index :tekomi_faq_suggestions, name: 'vector_idx_tekomi_faq_suggestions_embedding', if_exists: true
    remove_index :article_embeddings, name: 'index_article_embeddings_on_embedding', if_exists: true

    remove_column :tekomi_assistant_responses, :embedding if column_exists?(:tekomi_assistant_responses, :embedding)
    remove_column :tekomi_faq_suggestions, :embedding if column_exists?(:tekomi_faq_suggestions, :embedding)
    remove_column :article_embeddings, :embedding if column_exists?(:article_embeddings, :embedding)

    execute 'DROP EXTENSION IF EXISTS vector'
  end

  def down
    enable_extension 'vector'
    add_column :tekomi_assistant_responses, :embedding, :vector, limit: 1024 unless column_exists?(:tekomi_assistant_responses, :embedding)
    add_column :tekomi_faq_suggestions, :embedding, :vector, limit: 1024 unless column_exists?(:tekomi_faq_suggestions, :embedding)
    add_column :article_embeddings, :embedding, :vector, limit: 1024 unless column_exists?(:article_embeddings, :embedding)
  end
end
