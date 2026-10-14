class Api::V1::Accounts::LicensesController < Api::V1::Accounts::BaseController
  def show
    render json: Licensing::Summary.new(Current.account).as_json
  end
end
