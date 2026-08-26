class PbxCallEvent < ApplicationRecord
  belongs_to :phone_call, optional: true

  validates :pbx_id, :event_id, :linked_id, :event_type, presence: true
  validates :event_id, uniqueness: { scope: :pbx_id }
end
