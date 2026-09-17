class Api::V1::Accounts::Contacts::DealsController < Api::V1::Accounts::Contacts::BaseController
  include CrmDealsFeatureConcern

  def index
    authorize Deal, :index?
    @deals = @contact.deals.includes(:contact, :assignee).order(created_at: :desc)
  end
end
