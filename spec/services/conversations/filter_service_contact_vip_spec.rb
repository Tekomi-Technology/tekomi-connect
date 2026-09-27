require 'rails_helper'

describe Conversations::FilterService do
  let!(:account) { create(:account) }
  let!(:user) { create(:user, account: account, role: :administrator) }
  let!(:inbox) { create(:inbox, account: account) }
  let!(:vip_contact) { create(:contact, account: account, vip: true) }
  let!(:regular_contact) { create(:contact, account: account) }
  let!(:vip_conversation) { create(:conversation, account: account, inbox: inbox, contact: vip_contact, status: 'open') }
  let!(:regular_conversation) { create(:conversation, account: account, inbox: inbox, contact: regular_contact, status: 'open') }

  before do
    create(:inbox_member, user: user, inbox: inbox)
  end

  def filter(payload)
    described_class.new({ payload: payload, page: 1 }.with_indifferent_access, user, account).perform
  end

  def condition(operator, values, query_operator = nil)
    { attribute_key: 'contact_vip', filter_operator: operator, values: values, query_operator: query_operator }.with_indifferent_access
  end

  it 'returns only conversations of VIP contacts when equal to true' do
    result = filter([condition('equal_to', [true])])

    expect(result[:conversations].map(&:id)).to contain_exactly(vip_conversation.id)
    expect(result[:count][:all_count]).to eq(1)
  end

  it 'returns conversations of non-VIP contacts when equal to false' do
    result = filter([condition('equal_to', [false])])

    expect(result[:conversations].map(&:id)).to contain_exactly(regular_conversation.id)
  end

  it 'excludes conversations of VIP contacts when not equal to true' do
    result = filter([condition('not_equal_to', [true])])

    expect(result[:conversations].map(&:id)).to contain_exactly(regular_conversation.id)
  end

  it 'accepts string values sent by the filter UI' do
    result = filter([condition('equal_to', ['true'])])

    expect(result[:conversations].map(&:id)).to contain_exactly(vip_conversation.id)
  end

  it 'combines with other conditions' do
    vip_conversation.update!(status: 'resolved')
    create(:conversation, account: account, inbox: inbox, contact: vip_contact, status: 'open')

    status_condition = { attribute_key: 'status', filter_operator: 'equal_to', values: ['open'] }.with_indifferent_access
    result = filter([condition('equal_to', [true], 'AND'), status_condition])

    expect(result[:conversations].map(&:contact_id)).to eq([vip_contact.id])
    expect(result[:conversations].map(&:status)).to eq(['open'])
  end

  it 'ignores VIP contacts from other accounts' do
    other_account = create(:account)
    other_vip = create(:contact, account: other_account, vip: true)
    regular_conversation.update_columns(contact_id: other_vip.id) # rubocop:disable Rails/SkipsModelValidations

    result = filter([condition('equal_to', [true])])

    expect(result[:conversations].map(&:id)).to contain_exactly(vip_conversation.id)
  end

  it 'rejects unsupported operators' do
    expect { filter([condition('contains', [true])]) }.to raise_error(CustomExceptions::CustomFilter::InvalidOperator)
  end
end
