class AddCustomQuestionsToEvents < ActiveRecord::Migration[7.1]
  def change
    add_column :events, :custom_questions, :text
  end
end
