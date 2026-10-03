# Overview dashboard data, readable by every member of the account.
class Api::V2::Accounts::DashboardController < Api::V1::Accounts::BaseController
  def show
    return head :unprocessable_entity if permitted_params[:since].blank? || permitted_params[:until].blank?

    render json: V2::Reports::DashboardBuilder.new(account: Current.account, user: Current.user, params: permitted_params).build
  end

  private

  def permitted_params
    params.permit(:since, :until, :inbox_id, :group_by, :timezone_offset)
  end
end
