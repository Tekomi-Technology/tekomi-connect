class Pipeline < ApplicationRecord
  # Intake hands the ticket over on its own as soon as it carries enough to be dispatched;
  # the later stages wait for a person to act.
  TICKET_DEFAULT_STAGES = [
    { key: :intake, threshold_minutes: 15, auto_advance_fields: %w[description] },
    { key: :dispatch, threshold_minutes: 120 },
    { key: :field_work, threshold_minutes: 1440 },
    { key: :done, threshold_minutes: nil }
  ].freeze

  # The late lists open as a table because what matters there is comparing how late
  # tickets are, which columns show and a board does not.
  TICKET_DEFAULT_VIEW_TYPES = { all: :kanban, breached: :table, at_risk: :table, mine: :kanban }.freeze

  belongs_to :account
  has_many :stages, -> { order(:position, :id) }, class_name: 'PipelineStage', dependent: :delete_all, inverse_of: :pipeline
  has_many :deals, dependent: :destroy_async
  has_many :tickets, dependent: :destroy_async
  has_many :saved_views, dependent: :delete_all

  enum :pipeline_type, { sales: 0, ticket: 1 }, prefix: true, validate: true

  validates :name, presence: true

  before_create :append_position
  after_create :create_default_stages
  after_create :create_default_views

  private

  def append_position
    self.position = (account.pipelines.maximum(:position) || -1) + 1
  end

  def create_default_stages
    pipeline_type_ticket? ? create_default_ticket_stages : create_default_deal_stages
  end

  def create_default_deal_stages
    I18n.t('crm_deals.default_pipeline.stages').each_with_index do |(key, name), index|
      stages.create!(name: name, stage_type: key == :customer ? :won : :open, color: PipelineStage::DEFAULT_COLORS[index])
    end
  end

  def create_default_ticket_stages
    TICKET_DEFAULT_STAGES.each_with_index do |stage_config, index|
      stage = stages.create!(
        name: I18n.t("crm_tickets.default_pipeline.stages.#{stage_config[:key]}"),
        stage_type: stage_config[:key] == :done ? :won : :open,
        color: PipelineStage::DEFAULT_COLORS[index],
        auto_advance_fields: stage_config[:auto_advance_fields] || []
      )
      stage.create_ticket_stage_sla!(threshold_minutes: stage_config[:threshold_minutes]) if stage_config[:threshold_minutes]
    end
  end

  def create_default_views
    pipeline_type_ticket? ? create_default_ticket_views : create_default_deal_view
  end

  def create_default_deal_view
    saved_views.create!(account: account, object_type: :deal, view_type: :kanban, name: I18n.t('crm_deals.default_view.name'))
  end

  def create_default_ticket_views
    TICKET_DEFAULT_VIEW_TYPES.each do |key, view_type|
      saved_views.create!(
        account: account,
        object_type: :ticket,
        view_type: view_type,
        name: I18n.t("crm_tickets.default_views.#{key}.name"),
        filters: SavedView::TICKET_DEFAULT_FILTERS.fetch(key)
      )
    end
  end
end
