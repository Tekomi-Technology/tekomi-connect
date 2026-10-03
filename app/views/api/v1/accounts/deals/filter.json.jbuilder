json.meta do
  json.count @count
  json.current_page @deals.current_page
  json.has_more @deals.next_page.present?
  json.stage_stats @stage_stats
end

json.payload do
  json.array! @deals do |deal|
    json.partial! 'api/v1/models/deal', formats: [:json], resource: deal
  end
end
