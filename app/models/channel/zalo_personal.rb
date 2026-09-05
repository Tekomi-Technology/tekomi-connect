# == Schema Information
#
# Table name: channel_zalo_personal
#
#  id                :bigint           not null, primary key
#  credentials       :text             not null
#  display_name      :string
#  last_connected_at :datetime
#  status            :string           not null
#  status_updated_at :datetime
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  account_id        :integer          not null
#  zalo_uid          :string           not null
#
# Indexes
#
#  index_channel_zalo_personal_on_zalo_uid  (zalo_uid) UNIQUE
#
class Channel::ZaloPersonal < ApplicationRecord
  include Channelable

  self.table_name = 'channel_zalo_personal'

  # TODO: Remove guard once encryption keys become mandatory (target 3-4 releases out).
  encrypts :credentials if Chatwoot.encryption_configured?

  # Channels are created by the QR login callback (not the generic inbox-create endpoint), and
  # credentials are only ever replaced by a fresh QR scan — so nothing here is user-editable.
  EDITABLE_ATTRS = [].freeze

  # `connected` is only ever set by the worker once a session is live. A channel starts as
  # `reconnecting` because the worker has not confirmed the session yet, and moves to `expired`
  # when the Zalo session genuinely died and a new QR scan is required.
  STATUSES = %w[connected reconnecting expired].freeze

  validates :zalo_uid, presence: true, uniqueness: true
  validates :credentials, presence: true
  validates :status, inclusion: { in: STATUSES }

  def name
    'Zalo Personal'
  end

  def parsed_credentials
    JSON.parse(credentials).symbolize_keys
  end

  def update_status!(new_status)
    update!(
      status: new_status,
      status_updated_at: Time.current,
      last_connected_at: new_status == 'connected' ? Time.current : last_connected_at
    )
  end
end

Channel::ZaloPersonal.prepend_mod_with('Channel::ZaloPersonal')
