class Api::V1::Accounts::TicketSourceConnectionsController < Api::V1::Accounts::BaseController
  include CrmTicketsFeatureConcern

  before_action :check_authorization
  before_action :fetch_connection, only: [:show, :update, :destroy, :test, :sync_statuses, :sync, :register_webhook, :unregister_webhook]

  rescue_from CustomExceptions::TicketSource::ApiError do |error|
    render_could_not_create_error(error.message)
  end

  def providers
    render json: TicketSources::Registry.providers.map { |provider|
      adapter_class = TicketSources::Registry.adapter_class(provider)
      { provider: provider, credential_fields: adapter_class.credential_fields, setting_fields: adapter_class.setting_fields }
    }
  end

  def index
    render json: { payload: Current.account.ticket_source_connections.order(:id).map { |connection| serialize(connection) } }
  end

  def show
    render json: serialize(@connection)
  end

  # Creating a connection verifies the credentials, learns the source's time zone and mirrors its statuses as stages.
  def create
    secret = params[:webhook_secret].presence || SecureRandom.hex(20)
    TicketSourceConnection.transaction do
      @connection = Current.account.ticket_source_connections.new(provider: params.require(:provider), name: params.require(:name),
                                                                  pipeline: pipeline_for_create, webhook_secret: secret)
      @connection.credential_values = permitted_values(:credentials, credential_keys)
      @connection.settings = permitted_values(:settings, setting_keys)
      @connection.save!
      remember_time_zone
      TicketSources::SyncService.new(@connection).sync_statuses
    end
    render json: serialize(@connection).merge(webhook_secret: secret), status: :created
  end

  def update
    @connection.credential_values = @connection.credential_values.merge(permitted_values(:credentials, credential_keys).compact_blank)
    @connection.settings = @connection.settings.merge(permitted_values(:settings, setting_keys))
    @connection.assign_attributes(params.slice(:name, :enabled, :webhook_secret).permit(:name, :enabled, :webhook_secret))
    @connection.save!
    render json: serialize(@connection)
  end

  def destroy
    unregister_webhook_quietly
    @connection.destroy!
    head :ok
  end

  def test
    render json: @connection.adapter.test_connection
  end

  def sync_statuses
    TicketSources::SyncService.new(@connection).sync_statuses
    render json: serialize(@connection.reload)
  end

  def sync
    TicketSources::ReconcileJob.perform_later(@connection.id)
    head :accepted
  end

  # Subscribes the source to this installation, so changes arrive without waiting for the periodic reconcile.
  def register_webhook
    unregister_webhook_quietly
    reference = @connection.adapter.register_webhook(@connection.webhook_url, @connection.webhook_secret)
    @connection.update!(settings: @connection.settings.merge('webhook_reference' => reference))
    render json: serialize(@connection)
  end

  def unregister_webhook
    @connection.adapter.unregister_webhook(@connection.settings.fetch('webhook_reference'))
    @connection.update!(settings: @connection.settings.except('webhook_reference'))
    render json: serialize(@connection)
  end

  private

  def check_authorization
    authorize TicketSourceConnection
  end

  def unregister_webhook_quietly
    reference = @connection.settings['webhook_reference']
    @connection.adapter.unregister_webhook(reference) if reference
  rescue CustomExceptions::TicketSource::ApiError => e
    Rails.logger.warn("[TicketSources] could not remove webhook #{reference} of connection #{@connection.id}: #{e.message}")
  end

  def fetch_connection
    @connection = Current.account.ticket_source_connections.find(params[:id])
  end

  def adapter_class
    TicketSources::Registry.adapter_class(@connection&.provider || params.require(:provider))
  end

  def credential_keys
    adapter_class.credential_fields.pluck(:key)
  end

  def setting_keys
    adapter_class.setting_fields.pluck(:key)
  end

  def permitted_values(name, keys)
    params.fetch(name, {}).permit(*keys).to_h
  end

  # Without an explicit pipeline the connection gets its own, holding only the stages mirrored from the source.
  def pipeline_for_create
    return Current.account.pipelines.find(params[:pipeline_id]) if params[:pipeline_id].present?

    Current.account.pipelines.create!(name: params.require(:name), pipeline_type: :ticket).tap { |pipeline| pipeline.stages.destroy_all }
  end

  def remember_time_zone
    info = @connection.adapter.test_connection
    @connection.update!(settings: @connection.settings.merge('time_zone' => info[:time_zone]))
  end

  def serialize(connection)
    secret_keys = connection.adapter.class.credential_fields.select { |field| field[:secret] }.pluck(:key)
    {
      id: connection.id, provider: connection.provider, name: connection.name, enabled: connection.enabled, pipeline_id: connection.pipeline_id,
      credentials: connection.credential_values.except(*secret_keys), settings: connection.settings, webhook_url: connection.webhook_url,
      webhook_registered: connection.settings['webhook_reference'].present?, last_synced_at: connection.last_synced_at, last_error: connection.last_error, linked_tickets: connection.external_links.count
    }
  end
end
