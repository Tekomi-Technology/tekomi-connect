class AddVipToCompanies < ActiveRecord::Migration[7.2]
  def change
    add_column :companies, :vip, :boolean, default: false, null: false
    add_index :companies, [:account_id, :vip], where: 'vip = true'
  end
end
