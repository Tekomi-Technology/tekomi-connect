class AddFrtStartedAtToAppliedSlas < ActiveRecord::Migration[7.2]
  def up
    add_column :applied_slas, :frt_started_at, :datetime

    # Running SLAs keep their current deadline: the first-response timer used to start at conversation creation.
    execute <<~SQL.squish
      UPDATE applied_slas
      SET frt_started_at = conversations.created_at
      FROM conversations
      WHERE conversations.id = applied_slas.conversation_id
    SQL
  end

  def down
    remove_column :applied_slas, :frt_started_at
  end
end
