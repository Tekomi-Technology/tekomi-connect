# Marks code that applies changes coming from an external source, so those writes are neither
# pushed back nor blocked by the lock that protects externally managed fields.
module TicketSources::SyncContext
  KEY = :ticket_source_sync

  def self.run
    previous = Thread.current[KEY]
    Thread.current[KEY] = true
    yield
  ensure
    Thread.current[KEY] = previous
  end

  def self.active?
    Thread.current[KEY] == true
  end
end
