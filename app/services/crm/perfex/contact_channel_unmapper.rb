module Crm
  module Perfex
    class ContactChannelUnmapper
      class UnmapError < StandardError; end

      pattr_initialize [:account!, :contact!, :conversation!]

      def perform
        ActiveRecord::Base.transaction do
          contact.reload.lock!
          conversation.reload.lock!
          conversation.contact_inbox.lock!
          validate!

          detached_contact = account.contacts.create!(
            name: conversation.contact_inbox.source_id.to_s,
            last_activity_at: conversations.maximum(:last_activity_at)
          )

          conversation_ids = conversations.pluck(:id)
          conversation.contact_inbox.update!(contact: detached_contact)
          conversations.update_all(contact_id: detached_contact.id, updated_at: Time.current)
          detach_customer_messages(conversation_ids, detached_contact)
          detach_conversation_records(conversation_ids, detached_contact)

          detached_contact
        end
      end

      private

      def validate!
        raise UnmapError, 'Contact does not belong to this account' unless contact.account_id == account.id
        raise UnmapError, 'Conversation does not belong to this contact' unless conversation.contact_id == contact.id
        raise UnmapError, 'Contact is not attached to a CRM customer' unless perfex_contact_id.present?
      end

      def perfex_contact_id
        contact.additional_attributes.dig('external', 'perfex_contact_id')
      end

      def conversations
        @conversations ||= account.conversations.where(contact_inbox_id: conversation.contact_inbox_id, contact_id: contact.id)
      end

      def detach_customer_messages(conversation_ids, detached_contact)
        Message.where(
          conversation_id: conversation_ids,
          sender_type: 'Contact',
          sender_id: contact.id
        ).update_all(sender_id: detached_contact.id, updated_at: Time.current)
      end

      def detach_conversation_records(conversation_ids, detached_contact)
        PhoneCall.where(conversation_id: conversation_ids, contact_id: contact.id)
                 .update_all(contact_id: detached_contact.id, updated_at: Time.current)
        CsatSurveyResponse.where(conversation_id: conversation_ids, contact_id: contact.id)
                          .update_all(contact_id: detached_contact.id, updated_at: Time.current)
        return unless defined?(::Call)

        ::Call.where(conversation_id: conversation_ids, contact_id: contact.id)
              .update_all(contact_id: detached_contact.id, updated_at: Time.current)
      end
    end
  end
end
