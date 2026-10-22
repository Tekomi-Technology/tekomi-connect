# Provider-neutral view of a ticket living in an external system. Adapters translate to and from this shape,
# so the sync service never sees provider payloads.
#   status:      { id:, name:, category: }  category is one of 'new', 'indeterminate', 'done'
#   assignee:    { id:, name: } or nil
#   comments:    [{ id:, body:, author:, created_at: }]
#   attachments: [{ id:, filename:, mime_type:, size:, content_url: }]
TicketSources::ExternalTicket = Struct.new(
  :id, :key, :url, :title, :description, :status, :assignee, :updated_at, :comments, :attachments,
  keyword_init: true
) do
  # Detects changes to the fields that are mirrored on the ticket itself. Comments and attachments
  # are reconciled by id, so they are not part of it.
  def fingerprint
    Digest::SHA256.hexdigest([title.to_s.strip, description.to_s.strip, status&.dig(:id), assignee&.dig(:id)].to_json)
  end
end
