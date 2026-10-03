class LlmPromptTemplate < ApplicationRecord
  validates :key, presence: true, uniqueness: true, inclusion: { in: ->(_record) { Llm::Prompts.keys } }
  validates :body, presence: true
  validate :body_is_valid_liquid

  private

  def body_is_valid_liquid
    Liquid::Template.parse(body)
  rescue Liquid::SyntaxError => e
    errors.add(:body, e.message)
  end
end
