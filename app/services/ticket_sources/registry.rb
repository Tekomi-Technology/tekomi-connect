# Maps a connection's provider key to the adapter class that speaks to that system.
# Supporting a new source (CRM, other ticketing tool, ...) is one adapter class plus one entry here.
module TicketSources::Registry
  ADAPTERS = { 'jira' => 'TicketSources::Jira::Adapter' }.freeze

  def self.providers
    ADAPTERS.keys
  end

  def self.adapter_class(provider)
    ADAPTERS.fetch(provider).constantize
  end

  def self.adapter_for(connection)
    adapter_class(connection.provider).new(connection)
  end
end
