class Api::V1::Accounts::Tickets::AttachmentsController < Api::V1::Accounts::BaseController
  include CrmTicketsFeatureConcern

  before_action :fetch_ticket

  def create
    authorize @ticket, :update?
    @ticket.attachments.attach(params.require(:file))
    blob = @ticket.attachments.blobs.order(:id).last
    TicketSources::PushAttachmentJob.perform_later(@ticket.id, blob.id) if @ticket.external_link
    render json: { id: blob.id, filename: blob.filename.to_s, content_type: blob.content_type, byte_size: blob.byte_size }, status: :created
  end

  private

  def fetch_ticket
    @ticket = Current.account.tickets.find(params[:ticket_id])
  end
end
