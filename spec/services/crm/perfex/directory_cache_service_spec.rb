require 'rails_helper'

RSpec.describe Crm::Perfex::DirectoryCacheService do
  let(:contact_client) { instance_double(Crm::Perfex::Api::ContactClient) }
  let(:contacts) do
    [
      { 'id' => '1', 'userid' => '10', 'firstname' => 'Jane', 'lastname' => 'Doe',
        'email' => 'jane@example.com', 'phonenumber' => '0901234567', 'unrelated' => 'field' }
    ]
  end

  before { Redis::Alfred.delete(described_class::CACHE_KEY) }
  after { Redis::Alfred.delete(described_class::CACHE_KEY) }

  describe '#fetch_all' do
    it 'crawls once and serves subsequent calls from the cache' do
      allow(contact_client).to receive(:fetch_all_contacts).and_return(contacts)

      first = described_class.new(contact_client).fetch_all
      second = described_class.new(contact_client).fetch_all

      expect(first).to eq(second)
      expect(contact_client).to have_received(:fetch_all_contacts).once
    end

    it 'caches only the fields needed for matching' do
      allow(contact_client).to receive(:fetch_all_contacts).and_return(contacts)

      expect(described_class.new(contact_client).fetch_all.first.keys)
        .to contain_exactly(*described_class::CACHED_FIELDS)
    end
  end

  describe '#refresh!' do
    it 'replaces the cached directory with a fresh crawl' do
      updated_contacts = [contacts.first.merge('email' => 'new@example.com')]
      allow(contact_client).to receive(:fetch_all_contacts).and_return(contacts, updated_contacts)

      service = described_class.new(contact_client)
      service.fetch_all
      service.refresh!

      expect(described_class.new(contact_client).fetch_all).to eq(
        [contacts.first.except('unrelated').merge('email' => 'new@example.com')]
      )
      expect(contact_client).to have_received(:fetch_all_contacts).twice
    end
  end
end
