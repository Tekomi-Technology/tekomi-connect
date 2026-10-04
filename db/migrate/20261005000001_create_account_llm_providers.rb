class CreateAccountLlmProviders < ActiveRecord::Migration[7.2]
  def change
    create_table :account_llm_providers do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.string :provider_type, null: false
      t.text :api_key, null: false

      t.timestamps
    end

    add_index :account_llm_providers, [:account_id, :provider_type], unique: true
  end
end
