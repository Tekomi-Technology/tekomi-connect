module RubyLLMChatMergedParams
  def with_params(**params)
    super(**RubyLLM::Utils.deep_merge(@params, params))
  end
end

RubyLLM::Chat.prepend(RubyLLMChatMergedParams)
