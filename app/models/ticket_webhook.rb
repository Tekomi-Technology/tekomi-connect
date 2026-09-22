## Lets an external system drop tickets into one pipeline without holding an agent's API
## token, which would otherwise grant it the whole account.
class TicketWebhook < ApplicationRecord
  belongs_to :account
  belongs_to :pipeline

  before_validation :assign_token, on: :create

  validates :name, :token, presence: true
  validates :token, uniqueness: true
  validates :name, uniqueness: { scope: :account_id }
  validate :pipeline_accepts_tickets

  scope :enabled, -> { where(enabled: true) }

  def endpoint_path
    "/webhooks/tickets/#{token}"
  end

  private

  def assign_token
    self.token ||= SecureRandom.urlsafe_base64(32)
  end

  def pipeline_accepts_tickets
    return if pipeline.blank?

    errors.add(:pipeline, :invalid) if pipeline.account_id != account_id || !pipeline.pipeline_type_ticket?
  end
end
