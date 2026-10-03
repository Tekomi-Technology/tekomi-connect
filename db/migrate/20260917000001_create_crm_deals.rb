class CreateCrmDeals < ActiveRecord::Migration[7.1]
  def change
    create_table :pipelines do |t|
      t.references :account, null: false, index: true
      t.string :name, null: false
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    create_table :pipeline_stages do |t|
      t.references :pipeline, null: false, index: true
      t.string :name, null: false
      t.string :color, null: false, default: '#6B7280'
      t.integer :position, null: false, default: 0
      t.integer :stage_type, null: false, default: 0
      t.timestamps
    end

    create_table :deals do |t|
      t.references :account, null: false, index: true
      t.references :pipeline, null: false, index: false
      t.references :stage, null: false, index: false
      t.references :contact, index: true
      t.references :assignee, index: true
      t.string :name, null: false
      t.bigint :value
      t.date :expected_close_date
      t.datetime :closed_at
      t.float :position, null: false, default: 0
      t.jsonb :custom_attributes, null: false, default: {}
      t.timestamps
    end
    add_index :deals, [:account_id, :pipeline_id, :stage_id, :position], name: 'index_deals_on_pipeline_stage_position'
    add_index :deals, :stage_id

    create_table :deal_conversations do |t|
      t.references :deal, null: false, index: false
      t.references :conversation, null: false, index: true
      t.timestamps
    end
    add_index :deal_conversations, [:deal_id, :conversation_id], unique: true

    create_table :deal_activities do |t|
      t.references :deal, null: false, index: true
      t.references :actor, index: false
      t.string :action, null: false
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end

    create_table :saved_views do |t|
      t.references :account, null: false, index: false
      t.references :pipeline, index: true
      t.integer :object_type, null: false, default: 0
      t.string :name, null: false
      t.string :icon
      t.integer :position, null: false, default: 0
      t.integer :view_type, null: false, default: 0
      t.jsonb :filters, null: false, default: []
      t.jsonb :sorts, null: false, default: []
      t.jsonb :fields, null: false, default: []
      t.string :group_by
      t.jsonb :settings, null: false, default: {}
      t.timestamps
    end
    add_index :saved_views, [:account_id, :object_type]
  end
end
