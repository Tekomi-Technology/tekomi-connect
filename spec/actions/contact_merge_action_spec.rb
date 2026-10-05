require 'rails_helper'

describe ContactMergeAction do
  subject(:contact_merge) { described_class.new(account: account, base_contact: base_contact, mergee_contact: mergee_contact).perform }

  let!(:account) { create(:account) }
  let!(:base_contact) do
    create(:contact, identifier: 'base_contact', email: 'old@old.com', phone_number: '', custom_attributes: { val_test: 'old', val_empty_old: '' },
                     account: account)
  end
  let!(:mergee_contact) do
    create(:contact, identifier: '', email: 'new@new.com', phone_number: '+12212345',
                     custom_attributes: { val_test: 'new', val_new: 'new', val_empty_new: '' }, account: account)
  end

  before do
    2.times.each do
      create(:conversation, contact: base_contact)
      create(:conversation, contact: mergee_contact)
      create(:message, sender: mergee_contact)
      create(:note, contact: mergee_contact, account: mergee_contact.account)
    end
  end

  describe '#perform' do
    it 'deletes mergee_contact' do
      contact_merge
      expect { mergee_contact.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it 'copies information from mergee contact to base contact' do
      contact_merge
      base_contact.reload
      expect(base_contact.identifier).to eq('base_contact')
      expect(base_contact.email).to eq('old@old.com')
      expect(base_contact.phone_number).to eq('+12212345')
      expect(base_contact.custom_attributes['val_test']).to eq('old')
      expect(base_contact.custom_attributes['val_new']).to eq('new')
      expect(base_contact.custom_attributes['val_empty_old']).to eq('')
      expect(base_contact.custom_attributes['val_empty_new']).to eq('')
    end

    context 'when base contact and merge contact are same' do
      it 'does not delete contact' do
        mergee_contact = base_contact
        contact_merge
        expect(mergee_contact.reload).not_to be_nil
      end
    end

    context 'when mergee contact has conversations' do
      it 'moves the conversations to base contact' do
        contact_merge
        expect(base_contact.conversations.count).to be 4
      end
    end

    context 'when mergee contact has contact inboxes' do
      it 'moves the contact inboxes to base contact' do
        contact_merge
        expect(base_contact.contact_inboxes.count).to be 4
      end
    end

    context 'when mergee contact has messages' do
      it 'moves the messages to base contact' do
        contact_merge
        expect(base_contact.messages.count).to be 2
      end
    end

    context 'when mergee contact has notes' do
      it 'moves the notes to base contact' do
        expect(base_contact.notes.count).to be 0
        expect(mergee_contact.notes.count).to be 2

        contact_merge

        expect(base_contact.reload.notes.count).to be 2
      end
    end

    context 'when the mergee owns records that belong to the person' do
      let(:conversation) { mergee_contact.conversations.first }
      let(:sales_pipeline) { Pipeline.create!(account: account, name: 'Sales') }
      let(:ticket_pipeline) { Pipeline.create!(account: account, name: 'Support', pipeline_type: :ticket) }

      it 'moves CSAT, analyses, emotion reports, calls, deals and tickets to the base contact' do
        create(:csat_survey_response, contact: mergee_contact, conversation: conversation, account: account)
        create(:call, contact: mergee_contact, conversation: conversation, account: account, inbox: conversation.inbox)
        ConversationAnalysis.create!(account: account, conversation: conversation, contact: mergee_contact,
                                     inbox: conversation.inbox, served_by: 'agent',
                                     quality: ConversationAnalysis::CRITERIA.index_with { { 'score' => 4 } })
        ConversationEmotionReport.create!(account: account, conversation: conversation, contact: mergee_contact, inbox: conversation.inbox)
        PhoneCall.create!(account: account, inbox: conversation.inbox, contact: mergee_contact, conversation: conversation,
                          pbx_id: 'pbx', linked_id: 'call-1', direction: 'inbound', customer_number: '+84901000001')
        Deal.create!(account: account, pipeline: sales_pipeline, stage: sales_pipeline.stages.create!(name: 'New'),
                     name: 'Hop dong 50tr', contact: mergee_contact)
        Ticket.create!(account: account, pipeline: ticket_pipeline, stage: ticket_pipeline.stages.create!(name: 'Open'),
                       title: 'Loi giao hang', contact: mergee_contact)

        contact_merge

        described_class::PERSON_RECORDS.each do |model_name|
          model = model_name.constantize
          expect(model.where(contact_id: mergee_contact.id)).to be_empty, "#{model_name} left on the mergee"
          expect(model.where(contact_id: base_contact.id)).to exist, "#{model_name} not moved to the base"
        end
      end

      it 'keeps one campaign membership when both contacts were recipients' do
        campaign = create(:campaign, account: account)
        CampaignRecipient.create!(account: account, campaign: campaign, inbox: campaign.inbox, contact: base_contact)
        CampaignRecipient.create!(account: account, campaign: campaign, inbox: campaign.inbox, contact: mergee_contact)

        contact_merge

        expect(CampaignRecipient.where(campaign: campaign).pluck(:contact_id)).to eq([base_contact.id])
      end
    end

    context 'when both contacts are linked to the CRM' do
      before do
        base_contact.update!(additional_attributes: { 'external' => { 'perfex_contact_id' => 7, 'perfex_customer_id' => 3 } })
        mergee_contact.update!(additional_attributes: { 'external' => { 'perfex_contact_id' => 9, 'perfex_customer_id' => 4 } })
      end

      it 'keeps the base link and records the mergee link' do
        contact_merge
        attributes = base_contact.reload.additional_attributes

        expect(attributes.dig('external', 'perfex_contact_id')).to eq(7)
        expect(attributes['merged_crm_links']).to contain_exactly(
          { 'perfex_contact_id' => 9, 'perfex_customer_id' => 4, 'contact_id' => mergee_contact.id }
        )
        expect(attributes['merged_contacts'].pluck('id')).to eq([mergee_contact.id])
      end
    end

    context 'when the mergee carries labels, VIP and a higher contact type' do
      it 'keeps them on the base contact' do
        mergee_contact.update!(vip: true, contact_type: :customer, label_list: ['zalo-vip'])
        base_contact.update!(contact_type: :lead)

        contact_merge
        base_contact.reload

        expect(base_contact.vip).to be(true)
        expect(base_contact.contact_type).to eq('customer')
        expect(base_contact.label_list).to include('zalo-vip')
      end
    end

    context 'when contacts belong to a different account' do
      it 'throws an exception' do
        new_account = create(:account)
        expect do
          described_class.new(account: new_account, base_contact: base_contact,
                              mergee_contact: mergee_contact).perform
        end.to raise_error('contact does not belong to the account')
      end
    end
  end
end
