module Enterprise::Deal
  def push_event_data
    company = contact&.company
    super.merge(company: company && { id: company.id, name: company.name })
  end
end
