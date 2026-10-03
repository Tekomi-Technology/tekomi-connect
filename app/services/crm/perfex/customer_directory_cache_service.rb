class Crm::Perfex::CustomerDirectoryCacheService < Crm::Perfex::DirectoryCacheService
  CACHE_KEY = 'crm:perfex:customer-directory:v1'.freeze
  CACHED_FIELDS = %w[userid company phonenumber].freeze

  private

  def fetch_source
    @client.fetch_all_customers
  end
end
