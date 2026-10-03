class PipelineStage < ApplicationRecord
  DEFAULT_COLORS = %w[#EF4444 #A855F7 #3B82F6 #10B981 #EAB308].freeze
  # Ticket fields a stage may require before it hands the ticket to the next stage on its own.
  AUTO_ADVANCE_FIELDS = %w[title description contact_id assignee_id].freeze

  belongs_to :pipeline
  has_many :deals, foreign_key: :stage_id, inverse_of: :stage, dependent: :restrict_with_exception
  has_many :tickets, foreign_key: :stage_id, inverse_of: :stage, dependent: :restrict_with_exception
  has_one :ticket_stage_sla, dependent: :destroy

  enum :stage_type, { open: 0, won: 1, lost: 2 }, validate: true

  validates :name, presence: true
  validate :auto_advance_fields_are_supported

  before_create :append_position

  def closed?
    won? || lost?
  end

  def next_stage
    pipeline.stages.where('position > ?', position).first
  end

  private

  def append_position
    self.position = (pipeline.stages.maximum(:position) || -1) + 1
  end

  def auto_advance_fields_are_supported
    unsupported = auto_advance_fields - AUTO_ADVANCE_FIELDS
    errors.add(:auto_advance_fields, :invalid) if unsupported.any?
  end
end
