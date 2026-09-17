class Api::V1::Accounts::SavedViewsController < Api::V1::Accounts::BaseController
  include CrmDealsFeatureConcern

  JSON_ATTRIBUTES = %i[filters sorts fields settings].freeze

  before_action :check_authorization
  before_action :fetch_saved_view, only: [:show, :update, :destroy]

  def index
    @saved_views = Current.account.saved_views.where(object_type: params.fetch(:object_type, 'deal')).order(:position, :id)
    @saved_views = @saved_views.where(pipeline_id: [params[:pipeline_id], nil]) if params[:pipeline_id].present?
  end

  def show; end

  def create
    @saved_view = Current.account.saved_views.create!(saved_view_params)
  end

  def update
    @saved_view.update!(saved_view_params)
  end

  def destroy
    @saved_view.destroy!
    head :ok
  end

  def reorder
    params.require(:ids).each_with_index do |id, index|
      Current.account.saved_views.where(id: id).update_all(position: index)
    end
    head :ok
  end

  private

  def fetch_saved_view
    @saved_view = Current.account.saved_views.find(params[:id])
  end

  def saved_view_params
    saved_view = params.require(:saved_view)
    saved_view.permit(:name, :icon, :pipeline_id, :object_type, :view_type, :group_by).merge(saved_view.slice(*JSON_ATTRIBUTES).permit!)
  end
end
