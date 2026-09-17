class PipelineStage < ApplicationRecord
  DEFAULT_COLORS = %w[#EF4444 #A855F7 #3B82F6 #10B981 #EAB308].freeze

  belongs_to :pipeline
  has_many :deals, foreign_key: :stage_id, inverse_of: :stage, dependent: :restrict_with_exception

  enum :stage_type, { open: 0, won: 1, lost: 2 }, validate: true

  validates :name, presence: true

  before_create :append_position

  def closed?
    won? || lost?
  end

  private

  def append_position
    self.position = (pipeline.stages.maximum(:position) || -1) + 1
  end
end
