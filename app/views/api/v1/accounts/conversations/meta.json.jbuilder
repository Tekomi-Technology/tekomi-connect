json.meta do
  json.mine_count @conversations_count[:mine_count]
  json.assigned_count @conversations_count[:assigned_count]
  json.unassigned_count @conversations_count[:unassigned_count]
  json.all_count @conversations_count[:all_count]
  json.vip_count @conversations_count[:vip_count]
  json.company_counts @conversations_count[:company_counts] if @conversations_count.key?(:company_counts)
end
