class CreateAiAlerts < ActiveRecord::Migration[7.2]
  def change
    create_table :ai_alerts do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.string :category, null: false
      t.string :feature
      t.string :provider
      t.string :title, null: false
      t.text :message, null: false
      t.string :fingerprint, null: false
      t.integer :status_code
      t.jsonb :metadata, null: false, default: {}
      t.integer :occurrences, null: false, default: 1
      t.datetime :last_seen_at, null: false
      t.datetime :read_at

      t.timestamps
    end

    add_index :ai_alerts, [:account_id, :created_at]
    add_index :ai_alerts, [:account_id, :read_at]
    add_index :ai_alerts, [:account_id, :fingerprint, :last_seen_at], name: 'index_ai_alerts_on_account_fingerprint_last_seen'
  end
end
