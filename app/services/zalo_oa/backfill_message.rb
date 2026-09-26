class ZaloOa::BackfillMessage
  IMAGE_TYPES = %w[photo image gif sticker].freeze
  FILE_TYPES = %w[file doc].freeze
  SUPPORTED_TYPES = (IMAGE_TYPES + FILE_TYPES + %w[text link audio video location]).freeze

  pattr_initialize [:channel!, :user_id!, :raw!]

  def to_params
    return if message_id.blank?

    {
      event_name: "#{self_message? ? 'oa' : 'user'}_send_#{event_type}",
      sender: { id: self_message? ? channel.oa_id : user_id },
      recipient: { id: self_message? ? user_id : channel.oa_id },
      message: message_payload,
      oa_id: channel.oa_id,
      timestamp: timestamp,
      backfill: true
    }.with_indifferent_access
  end

  private

  def data
    @data ||= raw.with_indifferent_access
  end

  def message_id
    data[:message_id].presence || data[:msg_id].presence
  end

  def timestamp
    data[:time].presence || data[:timestamp].presence || 0
  end

  def self_message?
    data.key?(:src) && data[:src].to_i.zero?
  end

  def event_type
    type = data[:type].to_s.downcase
    SUPPORTED_TYPES.include?(type) ? type : 'text'
  end

  def text
    value = data[:message].presence || data[:text].presence
    return value if value.is_a?(String) && value.present?
    return url.to_s if event_type == 'link'
    return location_text if event_type == 'location'

    value.is_a?(String) ? value : ''
  end

  def location_text
    coordinates = data[:coordinates] || data[:location] || {}
    coordinates = coordinates.with_indifferent_access if coordinates.respond_to?(:with_indifferent_access)
    latitude = coordinates[:latitude].presence || coordinates[:lat].presence || data[:latitude].presence
    longitude = coordinates[:longitude].presence || coordinates[:lng].presence || coordinates[:lon].presence || data[:longitude].presence
    return "📍 Vị trí: https://www.google.com/maps?q=#{latitude},#{longitude}" if latitude.present? && longitude.present?

    '📍 Vị trí'
  end

  def url
    data[:url].presence || data[:href].presence
  end

  def message_payload
    payload = { msg_id: message_id.to_s, text: text }
    payload[:attachments] = [attachment] if attachment.present?
    payload[:attachments] = [{ type: 'location', payload: { coordinates: location_coordinates } }] if event_type == 'location' && location_coordinates.present?
    payload
  end

  def location_coordinates
    coordinates = data[:coordinates] || data[:location] || {}
    coordinates = coordinates.with_indifferent_access if coordinates.respond_to?(:with_indifferent_access)
    latitude = coordinates[:latitude].presence || coordinates[:lat].presence || data[:latitude].presence
    longitude = coordinates[:longitude].presence || coordinates[:lng].presence || coordinates[:lon].presence || data[:longitude].presence
    return if latitude.blank? || longitude.blank?

    { latitude: latitude, longitude: longitude }
  end

  def attachment
    return if url.blank? || !url.match?(%r{\Ahttps?://}i)

    {
      type: event_type,
      payload: { url: url, name: data[:name].presence || File.basename(URI.parse(url).path).presence }
    }
  rescue URI::InvalidURIError
    nil
  end
end
