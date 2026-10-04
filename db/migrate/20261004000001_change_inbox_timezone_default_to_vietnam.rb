class ChangeInboxTimezoneDefaultToVietnam < ActiveRecord::Migration[7.2]
  # Only new inboxes are affected; existing inboxes keep their time zone.
  def change
    change_column_default :inboxes, :timezone, from: 'UTC', to: 'Asia/Ho_Chi_Minh'
  end
end
