class Api::V1::Accounts::Companies::DealsController < Api::V1::Accounts::Companies::BaseController
  include CrmDealsFeatureConcern

  before_action :authorize_company_read!

  def index
    authorize Deal, :index?
    @deals = Current.account.deals.where(contact_id: @company.contacts.select(:id))
                    .includes(:contact, :assignee)
                    .order(created_at: :desc)
  end
end
