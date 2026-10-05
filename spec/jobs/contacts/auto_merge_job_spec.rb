require 'rails_helper'

RSpec.describe Contacts::AutoMergeJob do
  let(:account) { create(:account) }

  it 'is enqueued when a contact gets a phone number' do
    contact = create(:contact, account: account)
    expect { contact.update!(phone_number: '0901000006') }.to have_enqueued_job(described_class).with(contact.id)
  end

  it 'merges duplicates when performed' do
    original = create(:contact, account: account, phone_number: '0901000007')
    duplicate = create(:contact, account: account, phone_number: '+84901000007')

    described_class.perform_now(duplicate.id)

    expect(Contact.exists?(duplicate.id)).to be(false)
    expect(Contact.exists?(original.id)).to be(true)
  end

  it 'does nothing for a contact that was already merged away' do
    expect { described_class.perform_now(-1) }.not_to raise_error
  end
end
