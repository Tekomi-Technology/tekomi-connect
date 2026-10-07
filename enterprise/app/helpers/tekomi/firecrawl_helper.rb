module Tekomi::FirecrawlHelper
  def generate_firecrawl_token(assistant_id, account)
    api_key = Firecrawl::Configuration.api_key(account: account)
    return nil unless api_key

    token_base = "#{api_key[-4..]}#{assistant_id}#{account.id}"
    Digest::SHA256.hexdigest(token_base)
  end
end
