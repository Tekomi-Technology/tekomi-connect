class Api::V2::Accounts::TicketReportsController < Api::V1::Accounts::BaseController
  include CrmTicketsFeatureConcern

  before_action :check_authorization

  def index
    @report = Tickets::ReportBuilder.new(
      account: Current.account,
      pipeline_id: params[:pipeline_id],
      range: report_range
    ).perform
  end

  private

  def check_authorization
    authorize :report, :view?
  end

  def report_range
    Date.iso8601(params.require(:since)).beginning_of_day..Date.iso8601(params.require(:until)).end_of_day
  end
end
