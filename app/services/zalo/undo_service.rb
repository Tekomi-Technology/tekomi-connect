# Mirrors a Zalo recall. The worker only forwards the operator's own recalls: a customer recall
# stays visible in Chatwoot on purpose, so the agent knows what was said and then withdrawn.
class Zalo::UndoService
  pattr_initialize [:inbox!, :params!]

  def perform
    message = inbox.messages.find_by(source_id: params[:recalled_msg_id].to_s)
    message&.destroy!
  end
end
