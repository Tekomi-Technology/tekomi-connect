class CreateChannelPhone < ActiveRecord::Migration[7.1]
  def change
    create_table :channel_phone do |t|
      t.integer :account_id, null: false
      t.string :wss_url, null: false
      t.string :sip_domain, null: false
      t.string :sip_username, null: false
      t.text :sip_password, null: false
      t.string :stun_url

      t.timestamps
    end

    add_index :channel_phone, [:account_id, :sip_domain, :sip_username], unique: true, name: 'idx_channel_phone_on_account_and_sip_identity'
  end
end
