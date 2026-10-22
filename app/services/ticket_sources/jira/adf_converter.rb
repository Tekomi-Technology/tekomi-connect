# Converts between Atlassian Document Format (the JSON Jira Cloud v3 uses for descriptions and comments)
# and the Markdown-flavoured plain text stored on tickets. Nodes with no text equivalent (media, ...) are dropped;
# unknown nodes keep whatever text they contain.
module TicketSources::Jira::AdfConverter
  INLINE_TYPES = %w[text hardBreak mention emoji inlineCard status date].freeze
  INLINE_PATTERN = /`([^`]+)`|\*\*(.+?)\*\*|~~(.+?)~~|\[([^\]]+)\]\(([^)\s]+)\)|\*([^*\s](?:[^*]*[^*\s])?)\*/

  module_function

  def to_text(adf)
    return '' if adf.blank?

    blocks_to_text(adf['content']).join("\n\n").strip
  end

  def from_text(text)
    lines = text.to_s.gsub("\r\n", "\n").split("\n", -1)
    { 'version' => 1, 'type' => 'doc', 'content' => parse_blocks(lines) }
  end

  def blocks_to_text(nodes)
    Array(nodes).map { |node| block_to_text(node) }.reject(&:empty?)
  end

  def block_to_text(node)
    case node['type']
    when 'heading' then "#{'#' * node.dig('attrs', 'level').to_i.clamp(1, 6)} #{inline_to_text(node['content'])}"
    when 'bulletList' then list_to_text(node) { '-' }
    when 'orderedList' then list_to_text(node) { |index| "#{index + 1}." }
    when 'codeBlock' then "```#{node.dig('attrs', 'language')}\n#{inline_to_text(node['content'])}\n```"
    when 'blockquote' then blocks_to_text(node['content']).join("\n\n").lines.map { |line| "> #{line}".rstrip }.join("\n")
    when 'rule' then '---'
    when 'table' then table_to_text(node)
    when 'media', 'mediaSingle', 'mediaGroup' then ''
    else generic_block_to_text(node)
    end
  end

  def generic_block_to_text(node)
    children = Array(node['content'])
    return inline_to_text(children) if children.all? { |child| INLINE_TYPES.include?(child['type']) }

    blocks_to_text(children).join("\n\n")
  end

  def list_to_text(node)
    Array(node['content']).each_with_index.map do |item, index|
      first, *rest = blocks_to_text(item['content']).join("\n").lines.map(&:chomp)
      (["#{yield(index)} #{first}"] + rest.map { |line| "  #{line}" }).join("\n")
    end.join("\n")
  end

  def table_to_text(node)
    Array(node['content']).map do |row|
      Array(row['content']).map { |cell| blocks_to_text(cell['content']).join(' ') }.join(' | ')
    end.join("\n")
  end

  def inline_to_text(nodes)
    Array(nodes).map { |node| inline_node_to_text(node) }.join
  end

  def inline_node_to_text(node)
    case node['type']
    when 'text' then apply_marks(node['text'].to_s, node['marks'])
    when 'hardBreak' then "\n"
    when 'mention', 'status' then node.dig('attrs', 'text').to_s
    when 'emoji' then (node.dig('attrs', 'text') || node.dig('attrs', 'shortName')).to_s
    when 'inlineCard' then node.dig('attrs', 'url').to_s
    when 'date' then Time.at(node.dig('attrs', 'timestamp').to_i / 1000).utc.strftime('%Y-%m-%d')
    else inline_to_text(node['content'])
    end
  end

  def apply_marks(text, marks)
    Array(marks).reduce(text) do |result, mark|
      case mark['type']
      when 'code' then "`#{result}`"
      when 'strong' then "**#{result}**"
      when 'em' then "*#{result}*"
      when 'strike' then "~~#{result}~~"
      when 'link' then "[#{result}](#{mark.dig('attrs', 'href')})"
      else result
      end
    end
  end

  def parse_blocks(lines)
    blocks = []
    paragraph = []
    index = 0
    while index < lines.size
      line = lines[index]
      if line.strip.empty?
        flush_paragraph(blocks, paragraph)
      elsif (fence = line.match(/\A```(\w*)\s*\z/))
        flush_paragraph(blocks, paragraph)
        code = lines[(index + 1)..].take_while { |code_line| code_line.strip != '```' }
        blocks << code_block(fence[1], code)
        index += code.size + 1
      elsif (heading = line.match(/\A(\#{1,6})\s+(.*)\z/))
        flush_paragraph(blocks, paragraph)
        blocks << { 'type' => 'heading', 'attrs' => { 'level' => heading[1].size }, 'content' => inline_from_text(heading[2]) }
      elsif line.match?(/\A---+\s*\z/)
        flush_paragraph(blocks, paragraph)
        blocks << { 'type' => 'rule' }
      elsif line.match?(/\A\s*([-*]|\d+[.)])\s+/)
        flush_paragraph(blocks, paragraph)
        items = lines[index..].take_while { |item| item.match?(/\A\s*([-*]|\d+[.)])\s+/) }
        blocks << list_block(items)
        index += items.size - 1
      elsif line.start_with?('>')
        flush_paragraph(blocks, paragraph)
        quote = lines[index..].take_while { |quote_line| quote_line.start_with?('>') }
        blocks << quote_block(quote)
        index += quote.size - 1
      else
        paragraph << line
      end
      index += 1
    end
    flush_paragraph(blocks, paragraph)
    blocks
  end

  def flush_paragraph(blocks, paragraph)
    return if paragraph.empty?

    content = paragraph.flat_map { |line| [{ 'type' => 'hardBreak' }] + inline_from_text(line) }.drop(1)
    blocks << { 'type' => 'paragraph', 'content' => content }
    paragraph.clear
  end

  def code_block(language, code)
    node = { 'type' => 'codeBlock' }
    node['attrs'] = { 'language' => language } if language.present?
    node['content'] = [{ 'type' => 'text', 'text' => code.join("\n") }] if code.any?(&:present?)
    node
  end

  def list_block(items)
    ordered = items.first.match?(/\A\s*\d/)
    list_items = items.map do |item|
      { 'type' => 'listItem',
        'content' => [{ 'type' => 'paragraph', 'content' => inline_from_text(item.sub(/\A\s*([-*]|\d+[.)])\s+/, '')) }] }
    end
    { 'type' => ordered ? 'orderedList' : 'bulletList', 'content' => list_items }
  end

  def quote_block(lines)
    text = lines.map { |line| line.sub(/\A>\s?/, '') }.join("\n")
    { 'type' => 'blockquote', 'content' => parse_blocks(text.split("\n", -1)) }
  end

  def inline_from_text(text)
    nodes = []
    cursor = 0
    text.to_enum(:scan, INLINE_PATTERN).map { Regexp.last_match }.each do |match|
      nodes << text_node(text[cursor...match.begin(0)])
      nodes << matched_node(match)
      cursor = match.end(0)
    end
    nodes << text_node(text[cursor..])
    nodes.compact
  end

  def matched_node(match)
    return text_node(match[1], 'code') if match[1]
    return text_node(match[2], 'strong') if match[2]
    return text_node(match[3], 'strike') if match[3]
    return text_node(match[4], 'link', 'href' => match[5]) if match[4]

    text_node(match[6], 'em')
  end

  def text_node(text, mark = nil, attrs = nil)
    return if text.nil? || text.empty?

    node = { 'type' => 'text', 'text' => text }
    node['marks'] = [{ 'type' => mark }.merge(attrs ? { 'attrs' => attrs } : {})] if mark
    node
  end
end
