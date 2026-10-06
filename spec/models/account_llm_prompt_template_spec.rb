# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccountLlmPromptTemplate, type: :model do
  let(:account) { create(:account) }

  it 'accepts a prompt key from the shared prompt catalog' do
    prompt = described_class.new(account: account, key: 'reply', body: 'Reply to {{ agent_name }}')

    expect(prompt).to be_valid
  end

  it 'rejects invalid Liquid syntax' do
    prompt = described_class.new(account: account, key: 'reply', body: '{{')

    expect(prompt).not_to be_valid
    expect(prompt.errors[:body]).to be_present
  end

  it 'scopes the key uniqueness to an account' do
    create(:account_llm_prompt_template, account: account, key: 'reply', body: 'first')
    prompt = described_class.new(account: account, key: 'reply', body: 'second')

    expect(prompt).not_to be_valid
    expect(prompt.errors[:key]).to be_present
  end

  it 'is selected before the global prompt and file default' do
    create(:account_llm_prompt_template, account: account, key: 'reply', body: 'Tenant prompt')

    expect(Llm::Prompts.body('reply', account: account)).to eq('Tenant prompt')
  end
end
