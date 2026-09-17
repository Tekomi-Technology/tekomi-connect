class Pipeline < ApplicationRecord
  belongs_to :account
  has_many :stages, -> { order(:position, :id) }, class_name: 'PipelineStage', dependent: :delete_all, inverse_of: :pipeline
  has_many :deals, dependent: :destroy_async
  has_many :saved_views, dependent: :delete_all

  validates :name, presence: true

  before_create :append_position
  after_create :create_default_stages
  after_create :create_default_view

  private

  def append_position
    self.position = (account.pipelines.maximum(:position) || -1) + 1
  end

  def create_default_stages
    I18n.t('crm_deals.default_pipeline.stages').each_with_index do |(key, name), index|
      stages.create!(name: name, stage_type: key == :customer ? :won : :open, color: PipelineStage::DEFAULT_COLORS[index])
    end
  end

  def create_default_view
    saved_views.create!(account: account, object_type: :deal, view_type: :kanban, name: I18n.t('crm_deals.default_view.name'))
  end
end
