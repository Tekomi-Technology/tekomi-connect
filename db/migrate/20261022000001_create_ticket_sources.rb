class CreateTicketSources < ActiveRecord::Migration[7.2]
  def change
    create_table :ticket_source_connections do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.references :pipeline, null: false, foreign_key: { on_delete: :cascade }
      t.string :provider, null: false
      t.string :name, null: false
      t.boolean :enabled, null: false, default: true
      t.text :credentials
      t.text :webhook_secret
      t.string :webhook_token, null: false
      t.jsonb :settings, null: false, default: {}
      t.datetime :last_synced_at
      t.text :last_error
      t.timestamps
    end
    add_index :ticket_source_connections, :webhook_token, unique: true
    add_index :ticket_source_connections, %i[account_id name], unique: true

    create_table :ticket_external_links do |t|
      t.references :ticket, null: false, index: { unique: true }, foreign_key: { on_delete: :cascade }
      t.references :connection, null: false, foreign_key: { to_table: :ticket_source_connections, on_delete: :cascade }
      t.string :external_id, null: false
      t.string :external_key
      t.string :external_url
      t.string :external_hash
      t.string :local_hash
      t.datetime :external_updated_at
      t.jsonb :external_data, null: false, default: {}
      t.timestamps
    end
    add_index :ticket_external_links, %i[connection_id external_id], unique: true
  end
end
