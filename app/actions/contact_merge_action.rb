class ContactMergeAction
  include Events::Types
  pattr_initialize [:account!, :base_contact!, :mergee_contact!]

  def perform
    # This case happens when an agent updates a contact email in dashboard,
    # while the contact also update his email via email collect box
    return @base_contact if base_contact.id == mergee_contact.id

    mergee_company_id = @mergee_contact.company_id
    ActiveRecord::Base.transaction do
      validate_contacts
      merge_conversations
      merge_messages
      merge_contact_inboxes
      merge_contact_notes
      merge_and_remove_mergee_contact
      preserve_company(mergee_company_id)
    end
    @base_contact
  end

  private

  def validate_contacts
    return if belongs_to_account?(@base_contact) && belongs_to_account?(@mergee_contact)

    raise StandardError, 'contact does not belong to the account'
  end

  def belongs_to_account?(contact)
    @account.id == contact.account_id
  end

  def merge_conversations
    Conversation.where(contact_id: @mergee_contact.id).update(contact_id: @base_contact.id)
  end

  def merge_contact_notes
    Note.where(contact_id: @mergee_contact.id, account_id: @mergee_contact.account_id).update(contact_id: @base_contact.id)
  end

  def merge_messages
    Message.where(sender: @mergee_contact).update(sender: @base_contact)
  end

  def merge_contact_inboxes
    ContactInbox.where(contact_id: @mergee_contact.id).update(contact_id: @base_contact.id)
  end

  def merge_and_remove_mergee_contact
    mergable_attribute_keys = %w[identifier name email phone_number additional_attributes custom_attributes]
    base_contact_attributes = base_contact.attributes.slice(*mergable_attribute_keys).compact_blank
    mergee_contact_attributes = mergee_contact.attributes.slice(*mergable_attribute_keys).compact_blank

    # attributes in base contact are given preference
    merged_attributes = mergee_contact_attributes.deep_merge(base_contact_attributes)
    # legacy channel-mapping pointers are obsolete once identities are merged
    merged_attributes['additional_attributes'] =
      (merged_attributes['additional_attributes'] || {}).except('mapped_contact_id', 'mapped_contact_name')

    @mergee_contact.reload.destroy!
    Rails.configuration.dispatcher.dispatch(CONTACT_MERGED, Time.zone.now, contact: @base_contact,
                                                                           tokens: [@base_contact.contact_inboxes.filter_map(&:pubsub_token)])
    @base_contact.update!(merged_attributes)
  end

  # company_id is not part of the mergeable attribute set; keep the base
  # company when present, otherwise inherit the mergee's so a company link
  # never disappears through a merge.
  def preserve_company(mergee_company_id)
    return if @base_contact.company_id.present? || mergee_company_id.blank?

    @base_contact.update!(company_id: mergee_company_id)
  end
end
