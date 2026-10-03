class CreateChannelZaloPersonal < ActiveRecord::Migration[7.2]
  def change
    create_table :channel_zalo_personal do |t|
      t.integer :account_id, null: false
      t.string :zalo_uid, null: false
      t.string :display_name
      t.text :credentials, null: false
      t.string :status, null: false, default: 'reconnecting'
      t.datetime :status_updated_at
      t.datetime :last_connected_at

      t.timestamps
    end

    add_index :channel_zalo_personal, :zalo_uid, unique: true
  end
end
