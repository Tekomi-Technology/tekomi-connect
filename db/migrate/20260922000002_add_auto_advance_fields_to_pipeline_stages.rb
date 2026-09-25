class AddAutoAdvanceFieldsToPipelineStages < ActiveRecord::Migration[7.1]
  def change
    add_column :pipeline_stages, :auto_advance_fields, :jsonb, null: false, default: []
  end
end
