class TicketStageSla < ApplicationRecord
  belongs_to :pipeline_stage

  validates :threshold_minutes, numericality: { only_integer: true, greater_than: 0 }
  validates :warning_threshold_percent, numericality: { only_integer: true, greater_than: 0, less_than: 100 }
end
