class CreateConversationEmotionReports < ActiveRecord::Migration[7.2]
  def change
    create_table :conversation_emotion_reports do |t|
      t.references :conversation, null: false, foreign_key: true, index: { unique: true }
      t.references :account, null: false, foreign_key: true
      t.references :inbox, null: false, foreign_key: true
      t.references :contact, null: false, foreign_key: true
      t.references :assignee, foreign_key: { to_table: :users }
      t.string :status, null: false, default: 'pending'
      t.string :action_status, null: false, default: 'none'
      t.string :emotion
      t.string :emotion_color
      t.float :confidence
      t.jsonb :probabilities, null: false, default: {}
      t.text :reason
      t.bigint :analyzed_through_message_id
      t.bigint :processing_message_id
      t.datetime :resolved_at
      t.datetime :processed_at
      t.string :llm_model
      t.string :llm_provider
      t.text :error_message
      t.timestamps
    end

    add_index :conversation_emotion_reports, %i[account_id status]
    add_index :conversation_emotion_reports, %i[account_id emotion]
    add_index :conversation_emotion_reports, %i[account_id action_status]
  end
end
