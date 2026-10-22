json.attachments @ticket.attachments do |attachment|
  json.id attachment.id
  json.filename attachment.filename.to_s
  json.content_type attachment.content_type
  json.byte_size attachment.byte_size
  json.url url_for(attachment)
end
