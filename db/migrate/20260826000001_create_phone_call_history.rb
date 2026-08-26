class CreatePhoneCallHistory < ActiveRecord::Migration[7.1]
  def change
    create_table :phone_calls do |t|
      t.integer :account_id, null: false
      t.integer :inbox_id, null: false
      t.integer :contact_id, null: false
      t.integer :conversation_id, null: false
      t.integer :message_id
      t.integer :user_id
      t.bigint :phone_extension_id
      t.string :pbx_id, null: false
      t.string :linked_id, null: false
      t.string :last_event_id
      t.string :direction, null: false
      t.string :customer_number, null: false
      t.string :extension
      t.string :from_number
      t.string :to_number
      t.string :status, null: false, default: 'ringing'
      t.datetime :started_at
      t.datetime :answered_at
      t.datetime :ended_at
      t.integer :duration_seconds
      t.string :hangup_cause
      t.text :recording_url
      t.jsonb :metadata, default: {}, null: false

      t.timestamps
    end

    add_index :phone_calls, [:pbx_id, :linked_id], unique: true
    add_index :phone_calls, [:account_id, :contact_id]
    add_index :phone_calls, [:account_id, :conversation_id]
    add_index :phone_calls, :message_id, unique: true, where: 'message_id IS NOT NULL'

    create_table :pbx_call_events do |t|
      t.bigint :phone_call_id
      t.string :pbx_id, null: false
      t.string :event_id, null: false
      t.string :linked_id, null: false
      t.string :event_type, null: false
      t.jsonb :payload, default: {}, null: false
      t.datetime :processed_at

      t.timestamps
    end

    add_index :pbx_call_events, [:pbx_id, :event_id], unique: true
    add_index :pbx_call_events, [:pbx_id, :linked_id]
    add_index :pbx_call_events, :phone_call_id
    add_foreign_key :pbx_call_events, :phone_calls, on_delete: :cascade
  end
end
