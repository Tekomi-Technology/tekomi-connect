## Turns a payload posted by an external system into a ticket on the webhook's pipeline.
## Contacts are matched, never created, so a monitoring system that reports an unknown
## device cannot fill the address book; the ticket is simply left without a contact.
class Tickets::WebhookIntakeService
  class InvalidPayload < StandardError; end

  CONTACT_LOOKUP_KEYS = %w[identifier email phone_number].freeze

  pattr_initialize [:webhook!, :payload!]

  def perform
    raise InvalidPayload, 'title is required' if title.blank?
    raise InvalidPayload, 'pipeline has no stages' if first_stage.blank?

    account.tickets.create!(
      pipeline: webhook.pipeline,
      stage: first_stage,
      title: title,
      description: payload['description'].presence,
      contact: matching_contact,
      created_by: :webhook,
      custom_attributes: payload['custom_attributes'].presence || {}
    )
  end

  private

  delegate :account, to: :webhook

  def title
    payload['title'].to_s.strip
  end

  def first_stage
    @first_stage ||= webhook.pipeline.stages.first
  end

  def matching_contact
    lookup = CONTACT_LOOKUP_KEYS.filter_map do |key|
      value = payload.dig('contact', key).presence
      [key, value] if value
    end.first
    return if lookup.blank?

    account.contacts.find_by(lookup.first => lookup.last)
  end
end
