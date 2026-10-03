class ZaloOa::SharedInfoService
  pattr_initialize [:inbox!, :params!]

  def perform
    return if user_id.blank?

    contact_inbox = inbox.contact_inboxes.find_by(source_id: user_id)
    return if contact_inbox.blank?

    contact = contact_inbox.contact
    contact.update!(contact_attributes)
  end

  private

  def user_id
    params.dig(:sender, :id).to_s
  end

  def contact_attributes
    info = shared_info
    attributes = {}
    attributes[:name] = info[:name] if info[:name].present?
    attributes[:phone_number] = info[:phone_number] if info[:phone_number].present? && info[:phone_number].match?(/\A(\+[1-9]\d{1,14}|0\d{8,10})\z/)
    address = [info[:address], info[:district], info[:city]].compact_blank.join(', ')
    attributes[:location] = address if address.present?
    attributes
  end

  def shared_info
    info = params[:info] || params.dig(:message, :info) || params[:shared_info] || params.dig(:data, :shared_info) || params.dig(:data, :info) || params[:data]
    info = info.with_indifferent_access if info.respond_to?(:with_indifferent_access)
    {
      name: info&.[](:name).presence || info&.[](:display_name).presence,
      phone_number: info&.[](:phone).presence || info&.[](:phone_number).presence,
      address: info&.[](:address),
      city: info&.[](:city),
      district: info&.[](:district)
    }
  end
end
