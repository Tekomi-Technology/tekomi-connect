class Ticket < ApplicationRecord
  TRACKED_ATTRIBUTES = %w[stage_id assignee_id].freeze

  belongs_to :account
  belongs_to :pipeline
  belongs_to :stage, class_name: 'PipelineStage'
  belongs_to :contact, optional: true
  belongs_to :assignee, class_name: 'User', optional: true
  has_many :activities, -> { order(created_at: :desc) }, class_name: 'TicketActivity', dependent: :delete_all, inverse_of: :ticket
  has_many :stage_events, -> { order(entered_at: :desc) }, class_name: 'TicketStageEvent', dependent: :delete_all, inverse_of: :ticket
  has_many :ticket_conversations, dependent: :delete_all
  has_many :conversations, through: :ticket_conversations

  enum :created_by, { staff: 0, ai_chatbot: 1, ai_callbot: 2, webhook: 3 }, prefix: true, validate: true
  enum :sla_status, { on_track: 0, at_risk: 1, breached: 2, no_sla: 3 }, prefix: true, validate: true

  validates :title, presence: true
  validate :associations_belong_to_account

  before_validation :sync_pipeline_from_stage
  before_create :append_to_stage
  after_create_commit :log_creation, :open_stage_event
  after_update_commit :log_changes, :rotate_stage_event
  after_create_commit :dispatch_create_event
  after_update_commit :dispatch_update_event
  after_destroy_commit :dispatch_destroy_event
  after_create_commit :auto_advance_stage
  after_update_commit :auto_advance_stage, if: :auto_advance_inputs_changed?

  def current_stage_event
    stage_events.find_by(exited_at: nil)
  end

  def push_event_data
    {
      id: id,
      account_id: account_id,
      pipeline_id: pipeline_id,
      stage_id: stage_id,
      title: title,
      description: description,
      created_by: created_by,
      position: position,
      custom_attributes: custom_attributes,
      sla_status: sla_status,
      contact: contact&.push_event_data,
      assignee: assignee&.push_event_data,
      sla: current_stage_event&.push_event_data,
      created_at: created_at.to_i,
      updated_at: updated_at.to_i
    }
  end

  private

  def sync_pipeline_from_stage
    self.pipeline_id = stage.pipeline_id if stage
  end

  def append_to_stage
    self.position = (stage.tickets.maximum(:position) || 0) + 1
  end

  def associations_belong_to_account
    errors.add(:stage, :invalid) if stage && stage.pipeline.account_id != account_id
    errors.add(:contact, :invalid) if contact && contact.account_id != account_id
    errors.add(:assignee, :invalid) if assignee && !account.users.exists?(assignee.id)
  end

  def open_stage_event
    stage_events.create!(pipeline_stage: stage, entered_at: Time.current)
  end

  # Re-checked after entering a stage too, so a ticket that already satisfies several
  # stages walks through all of them instead of stopping at the first one.
  def auto_advance_inputs_changed?
    previous_changes.keys.intersect?(PipelineStage::AUTO_ADVANCE_FIELDS + ['stage_id'])
  end

  def auto_advance_stage
    ::Tickets::AutoAdvanceService.new(ticket: self).perform
  end

  def rotate_stage_event
    return unless previous_changes.key?('stage_id')

    current_stage_event&.update!(exited_at: Time.current)
    open_stage_event
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
    Rails.configuration.dispatcher.dispatch(TICKET_CREATED, Time.zone.now, ticket: self)
  end

  def dispatch_update_event
    Rails.configuration.dispatcher.dispatch(TICKET_UPDATED, Time.zone.now, ticket: self)
  end

  def dispatch_destroy_event
    Rails.configuration.dispatcher.dispatch(TICKET_DELETED, Time.zone.now,
                                            ticket_data: { id: id, account_id: account_id, pipeline_id: pipeline_id })
  end
end
