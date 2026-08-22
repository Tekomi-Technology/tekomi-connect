class Crm::Perfex::CustomerMatcherService
  def initialize(customer_client)
    @customer_client = customer_client
  end

  def match_all(contacts)
    customers = @customer_client.fetch_all_customers
    contacts.each { |contact| match_contact(contact, customers) }
  end

  def match_one(contact)
    customers = @customer_client.fetch_all_customers
    match_contact(contact, customers)
    contact
  end

  private

  def match_contact(contact, customers)
    if contact.phone_number.blank?
      mark_failed(contact)
      return
    end

    matched = customers.find { |customer| normalize(customer['phonenumber']) == normalize(contact.phone_number) }

    matched ? mark_matched(contact, matched) : mark_failed(contact)
  end

  def mark_matched(contact, customer)
    external = (contact.additional_attributes['external'] || {}).merge('perfex_id' => customer['userid'])
    crm = (contact.additional_attributes['crm'] || {}).merge('company' => customer['company'], 'matched_at' => Time.current.iso8601)
    crm.delete('match_failed_at')

    contact.update!(additional_attributes: contact.additional_attributes.merge('external' => external, 'crm' => crm))
  end

  def mark_failed(contact)
    already_failed = contact.additional_attributes.dig('external', 'perfex_id').blank? &&
                      contact.additional_attributes.dig('crm', 'match_failed_at').present?
    return if already_failed

    crm = (contact.additional_attributes['crm'] || {}).merge('match_failed_at' => Time.current.iso8601)
    contact.update!(additional_attributes: contact.additional_attributes.merge('crm' => crm))
  end

  def normalize(number)
    return '' if number.blank?

    digits = number.to_s.gsub(/\D/, '')
    digits = digits.delete_prefix('84') if digits.start_with?('84')
    digits.delete_prefix('0')
  end
end
