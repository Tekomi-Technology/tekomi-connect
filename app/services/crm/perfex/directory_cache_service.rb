class Crm::Perfex::DirectoryCacheService
  CACHE_KEY = 'crm:perfex:directory:v1'.freeze
  TTL = 24.hours
  CACHED_FIELDS = %w[id userid firstname lastname email phonenumber].freeze

  def initialize(client)
    @client = client
  end

  def fetch_all
    cached = read_cache
    return cached if cached

    records = fetch_source
    write_cache(records)
    records
  end

  def refresh!
    write_cache(fetch_source)
  end

  private

  def fetch_source
    @client.fetch_all_contacts
  end

  def read_cache
    raw = Redis::Alfred.get(self.class::CACHE_KEY)
    JSON.parse(raw) if raw.present?
  end

  def write_cache(records)
    payload = records.map { |record| record.slice(*self.class::CACHED_FIELDS) }
    Redis::Alfred.setex(self.class::CACHE_KEY, payload.to_json, TTL)
  end
end
