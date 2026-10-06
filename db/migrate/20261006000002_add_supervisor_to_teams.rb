class AddSupervisorToTeams < ActiveRecord::Migration[7.2]
  def change
    add_reference :teams, :supervisor, foreign_key: { to_table: :users }, null: true, index: true
  end
end
