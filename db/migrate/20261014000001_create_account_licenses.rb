class CreateAccountLicenses < ActiveRecord::Migration[7.2]
  def change
    create_table :account_licenses do |t|
      t.references :account, null: false, index: { unique: true }
      t.string :plan_key, null: false, default: 'custom'
      t.boolean :trial, null: false, default: false
      t.boolean :suspended, null: false, default: false
      t.boolean :enforce, null: false, default: false
      t.string :state, null: false, default: 'active'
      t.string :overage_policy, null: false, default: 'block'
      t.datetime :starts_at, null: false
      t.datetime :expires_at
      t.integer :grace_days, null: false, default: 3
      t.jsonb :quotas, null: false, default: {}
      t.jsonb :notified, null: false, default: {}
      t.timestamps
    end
    add_index :account_licenses, :state

    create_table :account_usage_counters do |t|
      t.references :account, null: false
      t.string :metric, null: false
      t.date :period_start, null: false
      t.bigint :used, null: false, default: 0
      t.timestamps
    end
    add_index :account_usage_counters, %i[account_id metric period_start], unique: true, name: 'index_usage_counters_on_account_metric_period'
  end
end
