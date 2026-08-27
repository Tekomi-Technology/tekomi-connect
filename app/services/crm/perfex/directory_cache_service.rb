class Crm::Perfex::DirectoryCacheService
  CACHE_KEY = 'crm:perfex:directory:v1'.freeze
  TTL = 24.hours
  CACHED_FIELDS = %w[id userid firstname lastname email phonenumber].freeze

  def initialize(contact_client)
    @contact_client = contact_client
  end

  def fetch_all
    cached = read_cache
    return cached if cached

    contacts = @contact_client.fetch_all_contacts
    write_cache(contacts)
    contacts
  end

  def refresh!
    write_cache(@contact_client.fetch_all_contacts)
  end

  private

  def read_cache
    raw = Redis::Alfred.get(CACHE_KEY)
    JSON.parse(raw) if raw.present?
  end

  def write_cache(contacts)
    payload = contacts.map { |contact| contact.slice(*CACHED_FIELDS) }
    Redis::Alfred.setex(CACHE_KEY, payload.to_json, TTL)
  end
end
