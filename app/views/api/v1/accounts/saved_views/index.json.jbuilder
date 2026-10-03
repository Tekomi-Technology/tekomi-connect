json.payload do
  json.array! @saved_views do |saved_view|
    json.partial! 'api/v1/models/saved_view', formats: [:json], resource: saved_view
  end
end
