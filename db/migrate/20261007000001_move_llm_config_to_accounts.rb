class MoveLlmConfigToAccounts < ActiveRecord::Migration[7.2]
  def up
    add_column :account_llm_providers, :api_base, :string
    change_column_null :account_llm_providers, :api_key, true

    execute(<<~SQL.squish)
      UPDATE account_llm_providers
      SET api_base = (SELECT api_base FROM llm_providers WHERE llm_providers.provider_type = account_llm_providers.provider_type)
      WHERE api_base IS NULL
    SQL

    create_table :account_llm_feature_models do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.string :feature_key, null: false
      t.string :provider_type, null: false
      t.string :model, null: false
      t.string :reasoning
      t.jsonb :params, null: false, default: {}

      t.timestamps
    end
    add_index :account_llm_feature_models, [:account_id, :feature_key], unique: true

    migrate_accounts

    drop_table :llm_feature_models
    drop_table :llm_providers
    drop_table :llm_prompt_templates
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def migrate_accounts
    global_feature_models = select_all(
      'SELECT f.feature_key, p.provider_type, f.model, f.reasoning, f.params ' \
      'FROM llm_feature_models f JOIN llm_providers p ON p.id = f.llm_provider_id'
    ).to_a
    global_prompts = select_all('SELECT key, body FROM llm_prompt_templates').to_a
    return if global_feature_models.blank? && global_prompts.blank?

    account_provider_types.each do |account_id, provider_types|
      default_pair = default_pair_for(global_feature_models, provider_types)
      apply_default_pair(account_id, default_pair)
      global_feature_models.each { |row| copy_feature_model(account_id, row, default_pair) }
      global_prompts.each { |row| copy_prompt(account_id, row) }
    end
  end

  def account_provider_types
    select_all('SELECT account_id, provider_type FROM account_llm_providers')
      .to_a
      .group_by { |row| row['account_id'] }
      .transform_values { |rows| rows.pluck('provider_type') }
  end

  def default_pair_for(global_feature_models, provider_types)
    eligible = global_feature_models.select { |row| provider_types.include?(row['provider_type']) && !fixed_features.key?(row['feature_key']) }
    return if eligible.blank?

    assistant = eligible.find { |row| row['feature_key'] == 'assistant' }
    return assistant.slice('provider_type', 'model') if assistant

    eligible.group_by { |row| row.slice('provider_type', 'model') }.max_by { |_pair, rows| rows.size }.first
  end

  def apply_default_pair(account_id, default_pair)
    return if default_pair.blank?

    settings = { llm_default_provider_type: default_pair['provider_type'], llm_default_model: default_pair['model'] }
    execute(
      "UPDATE accounts SET settings = COALESCE(settings, '{}'::jsonb) || #{connection.quote(settings.to_json)}::jsonb WHERE id = #{account_id.to_i}"
    )
  end

  def copy_feature_model(account_id, row, default_pair)
    params = row['params'].is_a?(String) ? JSON.parse(row['params'].presence || '{}') : (row['params'] || {})
    return if row['reasoning'].blank? && params.blank? && redundant_route?(row, default_pair)

    execute(
      'INSERT INTO account_llm_feature_models (account_id, feature_key, provider_type, model, reasoning, params, created_at, updated_at) ' \
      "VALUES (#{account_id.to_i}, #{connection.quote(row['feature_key'])}, #{connection.quote(row['provider_type'])}, " \
      "#{connection.quote(row['model'])}, #{connection.quote(row['reasoning'])}, #{connection.quote(params.to_json)}::jsonb, NOW(), NOW()) " \
      'ON CONFLICT (account_id, feature_key) DO NOTHING'
    )
  end

  def redundant_route?(row, default_pair)
    return true if fixed_features[row['feature_key']] == row.slice('provider_type', 'model')

    default_pair.present? && default_pair == row.slice('provider_type', 'model')
  end

  def copy_prompt(account_id, row)
    execute(
      'INSERT INTO account_llm_prompt_templates (account_id, key, body, created_at, updated_at) ' \
      "VALUES (#{account_id.to_i}, #{connection.quote(row['key'])}, #{connection.quote(row['body'])}, NOW(), NOW()) " \
      'ON CONFLICT (account_id, key) DO NOTHING'
    )
  end

  def fixed_features
    @fixed_features ||= YAML.load_file(Rails.root.join('config/llm.yml'))
                            .fetch('features')
                            .select { |_key, config| config.key?('model') }
                            .transform_values { |config| { 'provider_type' => config['provider_type'], 'model' => config['model'] } }
  end
end
