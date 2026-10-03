class Api::V1::Accounts::Conversations::DealsController < Api::V1::Accounts::Conversations::BaseController
  include CrmDealsFeatureConcern

  def index
    authorize Deal, :index?
    @deals = @conversation.deals.includes(:contact, :assignee).order(created_at: :desc)
  end
end
