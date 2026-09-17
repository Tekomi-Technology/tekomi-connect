class AddExpectedCloseDateIndexToDeals < ActiveRecord::Migration[7.1]
  def change
    add_index :deals, [:pipeline_id, :expected_close_date]
  end
end
