class CreatePhoneCallEmotionReports < ActiveRecord::Migration[7.2]
  def change
    create_table :phone_call_emotion_reports do |t|
      t.references :phone_call, null: false, foreign_key: true, index: { unique: true }
      t.references :account, null: false, foreign_key: true
      t.references :conversation, null: false, foreign_key: true
      t.references :inbox, null: false, foreign_key: true
      t.string :status, null: false, default: 'pending'
      t.string :purpose, null: false, default: 'monitoring'
      t.string :action_status, null: false, default: 'none'
      t.string :emotion
      t.string :emotion_color
      t.text :reason
      t.text :transcript
      t.string :asr_model
      t.string :asr_provider
      t.string :asr_runtime
      t.string :llm_model
      t.string :llm_provider
      t.text :error_message
      t.datetime :processed_at
      t.timestamps
    end

    add_index :phone_call_emotion_reports, %i[account_id status]
    add_index :phone_call_emotion_reports, %i[account_id emotion]
  end
end
