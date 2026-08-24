class Api::V1::Accounts::Inboxes::PhoneExtensionsController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?
  before_action :fetch_inbox
  before_action :fetch_extension, only: [:update, :destroy]

  def index
    render json: @inbox.phone_extensions.includes(:user).map { |extension| extension_payload(extension) }
  end

  def create
    extension = @inbox.phone_extensions.create!(extension_params.merge(account: Current.account))
    render json: extension_payload(extension), status: :created
  end

  def update
    attributes = extension_params
    attributes = attributes.except(:sip_password) if attributes[:sip_password].blank?
    @extension.update!(attributes)
    render json: extension_payload(@extension)
  end

  def destroy
    @extension.destroy!
    head :no_content
  end

  private

  def fetch_inbox
    @inbox = Current.account.inboxes.find(params[:inbox_id])
    return if @inbox.phone?

    head :not_found
  end

  def fetch_extension
    @extension = @inbox.phone_extensions.find(params[:id])
  end

  def extension_params
    params.require(:phone_extension).permit(:user_id, :sip_username, :sip_password, :enabled)
  end

  def extension_payload(extension)
    {
      id: extension.id,
      user_id: extension.user_id,
      user_name: extension.user.name,
      sip_username: extension.sip_username,
      enabled: extension.enabled,
      password_configured: extension.sip_password.present?
    }
  end
end
