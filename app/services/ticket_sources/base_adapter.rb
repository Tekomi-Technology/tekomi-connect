# Contract every ticket source implements. Methods returning tickets return TicketSources::ExternalTicket.
class TicketSources::BaseAdapter
  # Fields the dashboard renders to collect credentials and settings for this provider.
  def self.credential_fields
    []
  end

  def self.setting_fields
    []
  end

  pattr_initialize :connection

  # Raises unless the request really comes from the source system.
  def verify_webhook!(_raw_body, _headers)
    raise NotImplementedError
  end

  # Returns { type: :ticket_changed | :ticket_deleted | :ignored, external_id: }.
  def parse_webhook(_payload)
    raise NotImplementedError
  end

  # Whether a ticket fetched from the source belongs to what this connection mirrors.
  def in_scope?(_external)
    true
  end

  def test_connection
    raise NotImplementedError
  end

  def statuses
    raise NotImplementedError
  end

  def fetch_ticket(_external_id)
    raise NotImplementedError
  end

  # Yields every ticket changed since `time` (everything when nil).
  def each_ticket_updated_since(_time, &)
    raise NotImplementedError
  end

  def create_ticket(_ticket)
    raise NotImplementedError
  end

  def update_ticket(_external_id, title: nil, description: nil)
    raise NotImplementedError
  end

  def add_comment(_external_id, _text)
    raise NotImplementedError
  end

  def add_attachment(_external_id, _filename, _content_type, _io)
    raise NotImplementedError
  end

  def download_attachment(_attachment)
    raise NotImplementedError
  end

  # Text in the shape it has after a round trip through the source, so local and remote text compare equal.
  def canonical_text(text)
    text.to_s.strip
  end
end
