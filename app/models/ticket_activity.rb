class TicketActivity < ApplicationRecord
  NOTE_ACTION = 'note'.freeze

  belongs_to :ticket
  belongs_to :actor, class_name: 'User', optional: true

  validates :action, presence: true
  validates :content, presence: true, if: :note?

  after_create_commit :push_to_external_source, if: -> { note? && actor_id && ticket.external_link }

  def note?
    action == NOTE_ACTION
  end

  def content
    metadata['content']
  end

  private

  def push_to_external_source
    TicketSources::PushCommentJob.perform_later(id)
  end
end
