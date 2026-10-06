class CreateAccountLlmPromptTemplates < ActiveRecord::Migration[7.2]
  def change
    create_table :account_llm_prompt_templates do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.string :key, null: false
      t.text :body, null: false

      t.timestamps
    end

    add_index :account_llm_prompt_templates, [:account_id, :key], unique: true
  end
end
