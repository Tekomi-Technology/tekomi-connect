class CreateConversationAnalyses < ActiveRecord::Migration[7.2]
  def change
    create_table :conversation_analyses do |t|
      t.references :account, null: false
      t.references :conversation, null: false, index: { unique: true }
      t.references :contact, null: false
      t.references :inbox, null: false
      t.references :assignee
      t.references :analyzed_by
      t.string :served_by, null: false
      t.integer :quality_score
      t.jsonb :quality, null: false, default: {}
      t.jsonb :customer, null: false, default: {}
      t.jsonb :insight, null: false, default: {}
      t.jsonb :conversation_state, null: false, default: {}
      t.jsonb :care, null: false, default: {}

      t.timestamps
    end
  end
end
