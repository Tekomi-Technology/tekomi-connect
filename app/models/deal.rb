class Deal < ApplicationRecord
  TRACKED_ATTRIBUTES = %w[stage_id value assignee_id].freeze

  belongs_to :account
  belongs_to :pipeline
  belongs_to :stage, class_name: 'PipelineStage'
  belongs_to :contact, optional: true
  belongs_to :assignee, class_name: 'User', optional: true
  has_many :deal_conversations, dependent: :delete_all
  has_many :conversations, through: :deal_conversations
  has_many :activities, -> { order(created_at: :desc) }, class_name: 'DealActivity', dependent: :delete_all, inverse_of: :deal

  validates :name, presence: true
  validates :value, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validate :associations_belong_to_account

  before_validation :sync_pipeline_from_stage
  before_create :append_to_stage
  before_save :sync_closed_at, if: :will_save_change_to_stage_id?
  after_create_commit :log_creation
  after_update_commit :log_changes
  after_create_commit :dispatch_create_event
  after_update_commit :dispatch_update_event
  after_destroy_commit :dispatch_destroy_event

  def push_event_data
    {
      id: id,
      account_id: account_id,
      pipeline_id: pipeline_id,
      stage_id: stage_id,
      name: name,
      value: value,
      expected_close_date: expected_close_date,
      closed_at: closed_at&.to_i,
      position: position,
      custom_attributes: custom_attributes,
      contact: contact&.push_event_data,
      assignee: assignee&.push_event_data,
      created_at: created_at.to_i,
      updated_at: updated_at.to_i
    }
  end

  private

  def sync_pipeline_from_stage
    self.pipeline_id = stage.pipeline_id if stage
  end

  def append_to_stage
    self.position = (stage.deals.maximum(:position) || 0) + 1
  end

  def sync_closed_at
    self.closed_at = stage.closed? ? Time.current : nil
  end

  def associations_belong_to_account
    errors.add(:stage, :invalid) if stage && stage.pipeline.account_id != account_id
    errors.add(:contact, :invalid) if contact && contact.account_id != account_id
    errors.add(:assignee, :invalid) if assignee && !account.users.exists?(assignee.id)
  end

  def log_creation
    activities.create!(actor: Current.user, action: 'created')
  end

  def log_changes
    previous_changes.slice(*TRACKED_ATTRIBUTES).each do |attribute, (from, to)|
      activities.create!(actor: Current.user, action: "#{attribute.delete_suffix('_id')}_changed", metadata: { from: from, to: to })
    end
  end

  def dispatch_create_event
    Rails.configuration.dispatcher.dispatch(DEAL_CREATED, Time.zone.now, deal: self)
  end

  def dispatch_update_event
    Rails.configuration.dispatcher.dispatch(DEAL_UPDATED, Time.zone.now, deal: self)
  end

  def dispatch_destroy_event
    Rails.configuration.dispatcher.dispatch(DEAL_DELETED, Time.zone.now, deal_data: { id: id, account_id: account_id, pipeline_id: pipeline_id })
  end
end

Deal.prepend_mod_with('Deal')
