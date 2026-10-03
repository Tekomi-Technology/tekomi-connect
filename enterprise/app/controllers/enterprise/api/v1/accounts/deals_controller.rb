module Enterprise::Api::V1::Accounts::DealsController
  private

  def deal_preloads
    [{ contact: :company }, :assignee]
  end
end
