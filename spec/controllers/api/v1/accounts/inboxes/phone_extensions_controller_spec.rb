require 'rails_helper'

RSpec.describe 'Phone Extensions API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:phone_inbox) { create(:channel_phone, account: account).inbox }
  let(:path) { "/api/v1/accounts/#{account.id}/inboxes/#{phone_inbox.id}/phone_extensions" }

  before { create(:inbox_member, inbox: phone_inbox, user: agent) }

  it 'allows an administrator to create, list, update and delete an agent extension' do
    post path,
         headers: admin.create_new_auth_token,
         params: {
           phone_extension: {
             user_id: agent.id,
             sip_username: '1002',
             sip_password: 'secret-password',
             enabled: true
           }
         },
         as: :json

    expect(response).to have_http_status(:created)
    expect(response.parsed_body).to include(
      'user_id' => agent.id,
      'sip_username' => '1002',
      'enabled' => true,
      'password_configured' => true
    )
    expect(response.parsed_body).not_to have_key('sip_password')

    extension_id = response.parsed_body['id']
    get path, headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body.one?).to be(true)

    patch "#{path}/#{extension_id}",
          headers: admin.create_new_auth_token,
          params: { phone_extension: { sip_username: '1003', sip_password: '', enabled: false } },
          as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include('sip_username' => '1003', 'enabled' => false)
    expect(PhoneExtension.find(extension_id).sip_password).to eq('secret-password')

    delete "#{path}/#{extension_id}", headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:no_content)
    expect(PhoneExtension.exists?(extension_id)).to be(false)
  end

  it 'rejects an agent from managing SIP extensions' do
    get path, headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unauthorized)
  end

  it 'rejects extension management for a non-phone inbox' do
    inbox = create(:inbox, account: account)

    get "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}/phone_extensions",
        headers: admin.create_new_auth_token,
        as: :json

    expect(response).to have_http_status(:not_found)
  end
end
