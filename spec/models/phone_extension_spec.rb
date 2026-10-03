require 'rails_helper'

RSpec.describe PhoneExtension do
  subject(:extension) { build(:phone_extension, inbox: phone_inbox, account: account, user: user) }

  let(:account) { create(:account) }
  let(:phone_inbox) { create(:channel_phone, account: account).inbox }
  let(:user) { create(:user, account: account) }

  before { create(:inbox_member, inbox: phone_inbox, user: user) }

  it 'accepts an assigned user and phone inbox from the same account' do
    expect(extension).to be_valid
  end

  it 'rejects a user who is not assigned to the inbox' do
    phone_inbox.inbox_members.find_by!(user: user).destroy!

    expect(extension).not_to be_valid
    expect(extension.errors[:user]).to be_present
  end

  it 'rejects a non-phone inbox' do
    regular_inbox = create(:inbox, account: account)
    create(:inbox_member, inbox: regular_inbox, user: user)
    extension.inbox = regular_inbox

    expect(extension).not_to be_valid
    expect(extension.errors[:inbox]).to be_present
  end

  it 'allows only one extension per user in an inbox' do
    create(:phone_extension, inbox: phone_inbox, account: account, user: user)

    expect(extension).not_to be_valid
    expect(extension.errors[:user_id]).to be_present
  end
end
