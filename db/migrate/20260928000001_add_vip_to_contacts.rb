class AddVipToContacts < ActiveRecord::Migration[7.2]
  def change
    add_column :contacts, :vip, :boolean, default: false, null: false
    add_index :contacts, [:account_id, :vip], where: 'vip = true'
  end
end
