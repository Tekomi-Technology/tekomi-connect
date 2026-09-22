class CreateTicketWebhooks < ActiveRecord::Migration[7.1]
  def change
    create_table :ticket_webhooks do |t|
      t.references :account, null: false, foreign_key: true
      t.references :pipeline, null: false, foreign_key: true
      t.string :name, null: false
      t.string :token, null: false
      t.boolean :enabled, null: false, default: true
      t.timestamps
    end

    add_index :ticket_webhooks, :token, unique: true
    add_index :ticket_webhooks, [:account_id, :name], unique: true
  end
end
