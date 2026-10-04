class SuperAdmin::RoleMatricesController < SuperAdmin::ApplicationController
  def show
    @role_matrix = YAML.load_file(Rails.root.join('config/role_matrix.yml'))
  end
end
