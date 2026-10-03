class CreateCrmTickets < ActiveRecord::Migration[7.1]
  def change
    add_column :pipelines, :pipeline_type, :integer, null: false, default: 0

    create_table :tickets do |t|
      t.references :account, null: false, index: true
      t.references :pipeline, null: false, index: false
      t.references :stage, null: false, index: false
      t.references :contact, index: true
      t.references :assignee, index: true
      t.string :title, null: false
      t.text :description
      t.integer :created_by, null: false, default: 0
      t.integer :sla_status, null: false, default: 0
      t.float :position, null: false, default: 0
      t.jsonb :custom_attributes, null: false, default: {}
      t.timestamps
    end
    add_index :tickets, [:account_id, :pipeline_id, :stage_id, :position], name: 'index_tickets_on_pipeline_stage_position'
    add_index :tickets, :stage_id
    add_index :tickets, [:account_id, :sla_status]

    create_table :ticket_stage_slas do |t|
      t.references :pipeline_stage, null: false, index: { unique: true }
      t.integer :threshold_minutes, null: false
      t.integer :warning_threshold_percent, null: false, default: 80
      t.timestamps
    end

    create_table :ticket_stage_events do |t|
      t.references :ticket, null: false, index: false
      t.references :pipeline_stage, null: false, index: true
      t.datetime :entered_at, null: false
      t.datetime :due_at
      t.datetime :warn_at
      t.datetime :warned_at
      t.datetime :missed_at
      t.datetime :exited_at
      t.timestamps
    end
    add_index :ticket_stage_events, [:ticket_id, :entered_at]
    add_index :ticket_stage_events, :warn_at, where: 'exited_at IS NULL AND missed_at IS NULL',
                                              name: 'index_pending_ticket_stage_events_on_warn_at'

    create_table :ticket_activities do |t|
      t.references :ticket, null: false, index: true
      t.references :actor, index: false
      t.string :action, null: false
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end
  end
end
