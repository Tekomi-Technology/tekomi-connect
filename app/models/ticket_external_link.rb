# == Schema Information
#
# Table name: ticket_external_links
#
#  id                  :bigint           not null, primary key
#  external_data       :jsonb            not null
#  external_hash       :string
#  external_key        :string
#  external_updated_at :datetime
#  external_url        :string
#  local_hash          :string
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  connection_id       :bigint           not null
#  external_id         :string           not null
#  ticket_id           :bigint           not null
#
# Pairs a ticket with its counterpart in an external system and remembers what was last synced:
#   external_hash / local_hash  fingerprints of the external and local side right after the last sync
#   external_data               { 'base' => { 'title', 'description' }, 'status' => {...}, 'assignee' => {...} }
class TicketExternalLink < ApplicationRecord
  belongs_to :ticket
  belongs_to :connection, class_name: 'TicketSourceConnection'

  validates :external_id, presence: true

  def push_event_data
    { provider: connection.provider, key: external_key, url: external_url, status: external_data['status'], assignee: external_data['assignee'] }
  end
end
