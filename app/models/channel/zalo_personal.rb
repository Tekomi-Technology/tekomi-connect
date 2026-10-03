# == Schema Information
#
# Table name: channel_zalo_personal
#
#  id                :bigint           not null, primary key
#  credentials       :text             not null
#  display_name      :string
#  last_connected_at :datetime
#  proxy_enabled     :boolean          default(TRUE), not null
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
  # credentials are only ever replaced by a fresh QR scan. Only the proxy switch is editable.
  EDITABLE_ATTRS = [:proxy_enabled].freeze

  # `connected` is only ever set by the worker once a session is live. A channel starts as
  # `reconnecting` because the worker has not confirmed the session yet, and moves to `expired`
  # when the Zalo session genuinely died and a new QR scan is required.
  STATUSES = %w[connected reconnecting expired].freeze

  validates :zalo_uid, presence: true, uniqueness: true
  validates :credentials, presence: true
  validates :status, inclusion: { in: STATUSES }

  # The worker applies the proxy choice when it logs in, so a change only takes effect after it
  # reconnects the live session. An expired session has nothing to reconnect until a rescan.
  after_update_commit :reconnect_worker, if: -> { saved_change_to_proxy_enabled? && status != 'expired' }

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

  private

  def reconnect_worker
    ::Zalo::WorkerClient.connect(self)
  end
end

Channel::ZaloPersonal.prepend_mod_with('Channel::ZaloPersonal')
