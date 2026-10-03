json.meta do
  json.count @count
  json.current_page @tickets.current_page
  json.has_more @tickets.next_page.present?
  json.stage_stats @stage_stats
end

json.payload do
  json.array! @tickets do |ticket|
    json.partial! 'api/v1/models/ticket', formats: [:json], resource: ticket
  end
end
