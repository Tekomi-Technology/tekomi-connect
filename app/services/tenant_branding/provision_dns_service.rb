class TenantBranding::ProvisionDnsService
  BASE_URI = 'https://api.cloudflare.com/client/v4'.freeze

  class ProvisioningError < StandardError; end

  def initialize(profile:)
    @profile = profile
  end

  def perform
    record = existing_record
    response = record ? update_record(record.fetch('id')) : create_record
    data = parsed_result!(response)

    @profile.update_columns(
      cloudflare_dns_record_id: data.fetch('id'),
      provisioning_status: 'active',
      provisioning_error: nil,
      provisioned_at: Time.current,
      updated_at: Time.current
    )
  end

  private

  def existing_record
    response = HTTParty.get(
      records_url,
      headers: headers,
      query: { type: 'A', name: @profile.hostname, per_page: 1 }
    )
    Array(parsed_result!(response)).first
  end

  def create_record
    HTTParty.post(records_url, headers: headers, body: record_payload.to_json)
  end

  def update_record(record_id)
    HTTParty.put("#{records_url}/#{record_id}", headers: headers, body: record_payload.to_json)
  end

  def record_payload
    {
      type: 'A',
      name: @profile.hostname,
      content: @profile.origin_ip,
      ttl: 1,
      proxied: false,
      comment: "Managed by Tekomi tenant branding for account #{@profile.account_id}"
    }
  end

  def parsed_result!(response)
    body = response.parsed_response
    return body['result'] if response.success? && body['success']

    message = Array(body['errors']).filter_map { |error| error['message'] }.join(', ').presence || "HTTP #{response.code}"
    raise ProvisioningError, message
  end

  def records_url
    "#{BASE_URI}/zones/#{ENV.fetch('CLOUDFLARE_ZONE_ID')}/dns_records"
  end

  def headers
    {
      'Authorization' => "Bearer #{ENV.fetch('CLOUDFLARE_API_TOKEN')}",
      'Content-Type' => 'application/json'
    }
  end
end
