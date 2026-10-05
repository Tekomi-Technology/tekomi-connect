require 'rails_helper'

RSpec.describe Contacts::AutoMergeService do
  subject(:merge) { described_class.new(contact: contact).perform }

  let(:account) { create(:account) }

  context 'when another contact has the same phone number in another format' do
    let!(:zalo_contact) { create(:contact, account: account, name: 'Lan (Zalo)', phone_number: '0901000001') }
    let(:contact) { create(:contact, account: account, name: 'Lan (Phone)', phone_number: '+84901000001') }

    it 'merges into the oldest contact' do
      expect(merge).to eq(zalo_contact)
      expect(Contact.exists?(contact.id)).to be(false)
      expect(zalo_contact.reload.additional_attributes['merged_contacts'].pluck('id')).to eq([contact.id])
    end
  end

  context 'when another contact has the same email in another case' do
    let!(:email_contact) { create(:contact, account: account, email: 'lan@example.com') }
    let(:contact) { create(:contact, account: account, phone_number: '0901000002') }

    it 'merges once the email is added' do
      contact.update_columns(email: 'LAN@example.com') # rubocop:disable Rails/SkipsModelValidations

      expect(merge).to eq(email_contact)
      expect(email_contact.reload.phone_number).to eq('0901000002')
    end
  end

  context 'when the phone matches but the contacts look like different people' do
    let!(:colleague) { create(:contact, account: account, phone_number: '02838000000', email: 'a@company.vn') }
    let(:contact) { create(:contact, account: account, phone_number: '+842838000000', email: 'b@company.vn') }

    it 'keeps both for an agent to decide' do
      expect(merge).to eq(contact)
      expect(Contact.exists?(colleague.id)).to be(true)
    end
  end

  context 'when both contacts are linked to different CRM contacts' do
    let!(:other) do
      create(:contact, account: account, phone_number: '0901000003', additional_attributes: { 'external' => { 'perfex_contact_id' => 1 } })
    end
    let(:contact) do
      create(:contact, account: account, phone_number: '0901000003', additional_attributes: { 'external' => { 'perfex_contact_id' => 2 } })
    end

    it 'does not merge them' do
      merge
      expect(Contact.exists?(other.id)).to be(true)
      expect(Contact.exists?(contact.id)).to be(true)
    end
  end

  context 'when a contact is blocked' do
    let!(:blocked) { create(:contact, account: account, phone_number: '0901000004', blocked: true) }
    let(:contact) { create(:contact, account: account, phone_number: '0901000004') }

    it 'does not merge them' do
      merge
      expect(Contact.exists?(blocked.id)).to be(true)
    end
  end

  context 'when the match is in another account' do
    let!(:elsewhere) { create(:contact, phone_number: '0901000005') }
    let(:contact) { create(:contact, account: account, phone_number: '0901000005') }

    it 'leaves both accounts alone' do
      merge
      expect(Contact.exists?(elsewhere.id)).to be(true)
    end
  end
end
