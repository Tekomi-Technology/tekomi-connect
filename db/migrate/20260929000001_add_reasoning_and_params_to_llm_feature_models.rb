class AddReasoningAndParamsToLlmFeatureModels < ActiveRecord::Migration[7.2]
  def change
    add_column :llm_feature_models, :reasoning, :string
    add_column :llm_feature_models, :params, :jsonb, null: false, default: {}
  end
end
