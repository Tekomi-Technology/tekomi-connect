class DealActivity < ApplicationRecord
  belongs_to :deal
  belongs_to :actor, class_name: 'User', optional: true

  validates :action, presence: true
end
