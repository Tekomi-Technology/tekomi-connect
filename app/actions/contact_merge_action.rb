class ContactMergeAction
  include Events::Types
  pattr_initialize [:account!, :base_contact!, :mergee_contact!]

  # Records that belong to the person rather than to one channel identity. Destroying the mergee
  # would otherwise delete them (CSAT, analyses), orphan them (calls) or detach them (deals,
  # tickets); conversation_emotion_reports even has a foreign key that makes the destroy fail.
  PERSON_RECORDS = %w[CsatSurveyResponse ConversationAnalysis ConversationEmotionReport Deal Ticket PhoneCall Call].freeze
  CONTACT_TYPE_RANK = %w[visitor lead customer].freeze

  def perform
    # This case happens when an agent updates a contact email in dashboard,
    # while the contact also update his email via email collect box
    return @base_contact if base_contact.id == mergee_contact.id

    mergee_company_id = @mergee_contact.company_id
    mergee_labels = @mergee_contact.label_list
    mergee_flags = @mergee_contact.slice(:vip, :contact_type)
    ActiveRecord::Base.transaction do
      validate_contacts
      merge_conversations
      merge_messages
      merge_contact_inboxes
      merge_contact_notes
      merge_person_records
      merge_campaign_recipients
      merge_and_remove_mergee_contact
      preserve_company(mergee_company_id)
      preserve_labels_and_flags(mergee_labels, mergee_flags)
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

  # update_all on purpose: these rows only need re-pointing, and their own callbacks would
  # broadcast every historical record again.
  # rubocop:disable Rails/SkipsModelValidations
  def merge_person_records
    PERSON_RECORDS.filter_map(&:safe_constantize).each do |model|
      model.where(contact_id: @mergee_contact.id).update_all(contact_id: @base_contact.id)
    end
  end

  # A campaign lists each contact once; drop the mergee's copy where the base is already listed.
  def merge_campaign_recipients
    return unless defined?(CampaignRecipient)

    recipients = CampaignRecipient.where(contact_id: @mergee_contact.id)
    recipients.where(campaign_id: CampaignRecipient.where(contact_id: @base_contact.id).select(:campaign_id)).delete_all
    recipients.update_all(contact_id: @base_contact.id)
  end
  # rubocop:enable Rails/SkipsModelValidations

  def merge_and_remove_mergee_contact
    mergable_attribute_keys = %w[identifier name email phone_number additional_attributes custom_attributes]
    base_contact_attributes = base_contact.attributes.slice(*mergable_attribute_keys).compact_blank
    mergee_contact_attributes = mergee_contact.attributes.slice(*mergable_attribute_keys).compact_blank

    # attributes in base contact are given preference
    merged_attributes = mergee_contact_attributes.deep_merge(base_contact_attributes)
    # legacy channel-mapping pointers are obsolete once identities are merged
    merged_attributes['additional_attributes'] =
      merged_additional_attributes((merged_attributes['additional_attributes'] || {}).except('mapped_contact_id', 'mapped_contact_name'))

    @mergee_contact.reload.destroy!
    Rails.configuration.dispatcher.dispatch(CONTACT_MERGED, Time.zone.now, contact: @base_contact,
                                                                           tokens: [@base_contact.contact_inboxes.filter_map(&:pubsub_token)])
    @base_contact.update!(merged_attributes)
  end

  # The base keeps its own CRM link. A different link on the mergee is kept on record rather than
  # silently dropped, and every merge is logged so an automatic merge can be traced back.
  def merged_additional_attributes(attributes)
    mergee_crm = crm_link(@mergee_contact)
    if mergee_crm.present? && crm_link(@base_contact).present? && mergee_crm != crm_link(@base_contact)
      attributes['merged_crm_links'] = Array(attributes['merged_crm_links']) + [mergee_crm.merge('contact_id' => @mergee_contact.id)]
    end
    attributes['merged_contacts'] = Array(@base_contact.additional_attributes&.dig('merged_contacts')) +
                                    [{ 'id' => @mergee_contact.id, 'name' => @mergee_contact.name, 'merged_at' => Time.current.iso8601 }]
    attributes
  end

  def crm_link(contact)
    contact.additional_attributes&.dig('external')&.slice('perfex_contact_id', 'perfex_customer_id').presence
  end

  def preserve_labels_and_flags(mergee_labels, mergee_flags)
    @base_contact.add_labels(mergee_labels) if mergee_labels.present?
    updates = {}
    updates[:vip] = true if mergee_flags['vip'] && !@base_contact.vip
    if CONTACT_TYPE_RANK.index(mergee_flags['contact_type']).to_i > CONTACT_TYPE_RANK.index(@base_contact.contact_type).to_i
      updates[:contact_type] = mergee_flags['contact_type']
    end
    @base_contact.update!(updates) if updates.present?
  end

  # company_id is not part of the mergeable attribute set; keep the base
  # company when present, otherwise inherit the mergee's so a company link
  # never disappears through a merge.
  def preserve_company(mergee_company_id)
    return if @base_contact.company_id.present? || mergee_company_id.blank?

    @base_contact.update!(company_id: mergee_company_id)
  end
end
