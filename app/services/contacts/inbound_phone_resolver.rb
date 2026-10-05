class Contacts::InboundPhoneResolver
  def initialize(account, *candidates)
    @account = account
    @candidates = candidates.compact.map(&:to_s).reject(&:blank?)
  end

  # Finds an existing contact for an inbound phone identity: exact match
  # first, then a normalized-digits comparison so formatting differences
  # (+84 / 0 prefixes, spaces, dashes) cannot spawn duplicate contacts.
  def find_contact
    exact = @account.contacts.find_by(phone_number: @candidates)
    return exact if exact

    @candidates.each do |candidate|
      contact = @account.contacts.with_normalized_phone(candidate).order(:id).first
      return contact if contact
    end
    nil
  end
end
