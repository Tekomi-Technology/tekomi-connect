require 'liquid'

class Tekomi::PromptRenderer
  class SnippetFileSystem < Liquid::LocalFileSystem
    def initialize(root, pattern, account: nil)
      @account = account
      super(root, pattern)
    end

    def read_template_file(template_name)
      return Llm::Prompts.body(template_name, account: @account) if Llm::Prompts.key?(template_name)

      super
    end
  end

  class << self
    def render(template_name, context = {}, account: nil)
      account ||= Current.account if defined?(Current)
      template = load_template(template_name, account: account)
      liquid_template = Liquid::Template.parse(template)
      liquid_template.render(stringify_keys(context), registers: { file_system: snippet_file_system(account) })
    end

    private

    def load_template(template_name, account: nil)
      return Llm::Prompts.body(template_name, account: account) if Llm::Prompts.key?(template_name)

      template_path = Rails.root.join('enterprise', 'lib', 'tekomi', 'prompts', "#{template_name}.liquid")

      raise "Template not found: #{template_name}" unless File.exist?(template_path)

      File.read(template_path)
    end

    def snippet_file_system(account = nil)
      SnippetFileSystem.new(
        Rails.root.join('enterprise/lib/tekomi/prompts/snippets'),
        '%s.liquid',
        account: account
      )
    end

    def stringify_keys(hash)
      hash.deep_stringify_keys
    end
  end
end
