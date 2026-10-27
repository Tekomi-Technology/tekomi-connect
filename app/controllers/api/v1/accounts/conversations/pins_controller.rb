class Api::V1::Accounts::Conversations::PinsController < Api::V1::Accounts::Conversations::BaseController
  def create
    @conversation.conversation_pins.find_or_create_by!(user: Current.user, account: Current.account)
    render json: { pinned: true }
  end

  def destroy
    @conversation.conversation_pins.find_by(user: Current.user)&.destroy!
    render json: { pinned: false }
  end
end
