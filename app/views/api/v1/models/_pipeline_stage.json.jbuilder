json.id resource.id
json.pipeline_id resource.pipeline_id
json.name resource.name
json.color resource.color
json.position resource.position
json.stage_type resource.stage_type
json.auto_advance_fields resource.auto_advance_fields

if resource.ticket_stage_sla
  json.sla do
    json.threshold_minutes resource.ticket_stage_sla.threshold_minutes
    json.warning_threshold_percent resource.ticket_stage_sla.warning_threshold_percent
  end
end
