class CreateLlmPromptTemplates < ActiveRecord::Migration[7.2]
  def change
    create_table :llm_prompt_templates do |t|
      t.string :key, null: false
      t.text :body, null: false

      t.timestamps
    end

    add_index :llm_prompt_templates, :key, unique: true
  end
end
