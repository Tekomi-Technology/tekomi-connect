class TicketActivity < ApplicationRecord
  NOTE_ACTION = 'note'.freeze

  belongs_to :ticket
  belongs_to :actor, class_name: 'User', optional: true

  validates :action, presence: true
  validates :content, presence: true, if: :note?

  def note?
    action == NOTE_ACTION
  end

  def content
    metadata['content']
  end
end
