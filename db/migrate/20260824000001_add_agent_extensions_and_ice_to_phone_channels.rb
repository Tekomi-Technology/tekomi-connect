class AddAgentExtensionsAndIceToPhoneChannels < ActiveRecord::Migration[7.1]
  def up
    add_column :channel_phone, :ice_servers, :jsonb, default: [], null: false
    add_column :channel_phone, :turn_shared_secret, :text
    add_column :channel_phone, :turn_credential_ttl, :integer, default: 3600, null: false

    create_table :phone_extensions do |t|
      t.integer :account_id, null: false
      t.integer :inbox_id, null: false
      t.integer :user_id, null: false
      t.string :sip_username, null: false
      t.text :sip_password, null: false
      t.boolean :enabled, default: true, null: false

      t.timestamps
    end

    add_foreign_key :phone_extensions, :accounts, on_delete: :cascade
    add_foreign_key :phone_extensions, :inboxes, on_delete: :cascade
    add_foreign_key :phone_extensions, :users, on_delete: :cascade
    add_index :phone_extensions, [:inbox_id, :user_id], unique: true
    add_index :phone_extensions, [:inbox_id, :sip_username], unique: true
    add_index :phone_extensions, :account_id

    migrate_legacy_stun_urls
    migrate_legacy_extensions

    change_column_null :channel_phone, :sip_username, true
    change_column_null :channel_phone, :sip_password, true
  end

  def down
    execute <<~SQL.squish
      UPDATE channel_phone
      SET sip_username = CONCAT('removed-extension-', id),
          sip_password = 'removed-extension'
      WHERE sip_username IS NULL OR sip_password IS NULL
    SQL

    change_column_null :channel_phone, :sip_username, false
    change_column_null :channel_phone, :sip_password, false

    drop_table :phone_extensions
    remove_column :channel_phone, :turn_credential_ttl
    remove_column :channel_phone, :turn_shared_secret
    remove_column :channel_phone, :ice_servers
  end

  private

  def migrate_legacy_stun_urls
    execute <<~SQL.squish
      UPDATE channel_phone
      SET ice_servers = jsonb_build_array(jsonb_build_object('urls', jsonb_build_array(stun_url)))
      WHERE stun_url IS NOT NULL AND stun_url <> ''
    SQL
  end

  def migrate_legacy_extensions
    execute <<~SQL.squish
      INSERT INTO phone_extensions
        (account_id, inbox_id, user_id, sip_username, sip_password, enabled, created_at, updated_at)
      SELECT DISTINCT ON (inboxes.id)
        channel_phone.account_id,
        inboxes.id,
        inbox_members.user_id,
        channel_phone.sip_username,
        channel_phone.sip_password,
        TRUE,
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
      FROM channel_phone
      INNER JOIN inboxes
        ON inboxes.channel_type = 'Channel::Phone'
        AND inboxes.channel_id = channel_phone.id
      INNER JOIN inbox_members ON inbox_members.inbox_id = inboxes.id
      WHERE channel_phone.sip_username IS NOT NULL
        AND channel_phone.sip_password IS NOT NULL
      ORDER BY inboxes.id, inbox_members.id
    SQL
  end
end
