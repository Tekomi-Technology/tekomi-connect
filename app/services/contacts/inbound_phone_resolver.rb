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

    digits = @candidates.map { |candidate| PhoneNumberNormalizer.normalize(candidate) }.reject(&:blank?)
    return nil if digits.empty?

    @account.contacts.where.not(phone_number: [nil, '']).find do |contact|
      digits.include?(PhoneNumberNormalizer.normalize(contact.phone_number))
    end
  end
end
