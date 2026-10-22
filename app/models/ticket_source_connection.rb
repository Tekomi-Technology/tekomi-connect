# == Schema Information
#
# Table name: ticket_source_connections
#
#  id             :bigint           not null, primary key
#  credentials    :text
#  enabled        :boolean          default(TRUE), not null
#  last_error     :text
#  last_synced_at :datetime
#  name           :string           not null
#  provider       :string           not null
#  settings       :jsonb            not null
#  webhook_secret :text
#  webhook_token  :string           not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  account_id     :bigint           not null
#  pipeline_id    :bigint           not null
#
# Links a ticket pipeline of one account to a project in an external system (Jira, a CRM, ...).
class TicketSourceConnection < ApplicationRecord
  belongs_to :account
  belongs_to :pipeline
  has_many :external_links, class_name: 'TicketExternalLink', foreign_key: :connection_id, inverse_of: :connection, dependent: :delete_all

  encrypts :credentials
  encrypts :webhook_secret
  has_secure_token :webhook_token

  scope :enabled, -> { where(enabled: true) }

  validates :name, presence: true, uniqueness: { scope: :account_id }
  validates :provider, inclusion: { in: ->(_connection) { TicketSources::Registry.providers } }
  validate :pipeline_is_a_ticket_pipeline_of_the_account

  def adapter
    TicketSources::Registry.adapter_for(self)
  end

  def credential_values
    JSON.parse(credentials.presence || '{}')
  end

  def credential_values=(values)
    self.credentials = values.to_h.to_json
  end

  def webhook_url
    "#{ENV.fetch('FRONTEND_URL')}/webhooks/ticket_sources/#{webhook_token}"
  end

  def record_error(error)
    update_columns(last_error: error&.message.to_s.truncate(1000), updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
  end

  private

  def pipeline_is_a_ticket_pipeline_of_the_account
    errors.add(:pipeline, :invalid) unless pipeline && pipeline.account_id == account_id && pipeline.pipeline_type_ticket?
  end
end
