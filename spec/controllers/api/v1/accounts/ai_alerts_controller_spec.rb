# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::AiAlerts', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let!(:alert) { create(:ai_alert, account: account) }

  def json_response
    JSON.parse(response.body, symbolize_names: true)
  end

  it 'allows account administrators to list alerts' do
    get "/api/v1/accounts/#{account.id}/ai_alerts",
        headers: admin.create_new_auth_token,
        as: :json

    expect(response).to have_http_status(:success)
    expect(json_response[:data].first[:id]).to eq(alert.id)
    expect(json_response[:meta][:unread_count]).to eq(1)
  end

  it 'does not expose alerts to agents' do
    get "/api/v1/accounts/#{account.id}/ai_alerts",
        headers: agent.create_new_auth_token,
        as: :json

    expect(response).to have_http_status(:unauthorized)
  end

  it 'marks and deletes an alert' do
    patch "/api/v1/accounts/#{account.id}/ai_alerts/#{alert.id}",
          headers: admin.create_new_auth_token,
          params: { read: true },
          as: :json

    expect(response).to have_http_status(:success)
    expect(alert.reload.read_at).to be_present

    delete "/api/v1/accounts/#{account.id}/ai_alerts/#{alert.id}",
           headers: admin.create_new_auth_token,
           as: :json

    expect(response).to have_http_status(:no_content)
    expect(AiAlert.exists?(alert.id)).to be(false)
  end

  it 'marks all alerts as read' do
    create(:ai_alert, account: account)

    post "/api/v1/accounts/#{account.id}/ai_alerts/mark_all_read",
         headers: admin.create_new_auth_token,
         as: :json

    expect(response).to have_http_status(:no_content)
    expect(account.ai_alerts.unread).to be_empty
  end
end
