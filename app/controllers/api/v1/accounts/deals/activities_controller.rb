class Api::V1::Accounts::Deals::ActivitiesController < Api::V1::Accounts::BaseController
  include CrmDealsFeatureConcern

  def index
    deal = Current.account.deals.find(params[:deal_id])
    authorize deal, :show?
    @activities = deal.activities.includes(:actor)
  end
end
