require 'rails_helper'

RSpec.describe 'Super Admin Role matrix', type: :request do
  let(:super_admin) { create(:super_admin) }

  describe 'GET /super_admin/role_matrix' do
    context 'when it is an unauthenticated super admin' do
      it 'redirects to the login page' do
        get '/super_admin/role_matrix'
        expect(response).to have_http_status(:redirect)
      end
    end

    context 'when it is an authenticated super admin' do
      it 'shows every role and translates every row of config/role_matrix.yml' do
        sign_in(super_admin, scope: :super_admin)
        get '/super_admin/role_matrix'

        expect(response).to have_http_status(:success)
        expect(response.body).to include('Role matrix', 'Administrator', 'Supervisor', 'Agent')
        expect(response.body).not_to include('translation missing')
      end
    end
  end
end
