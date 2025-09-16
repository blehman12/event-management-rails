class CreateVenues < ActiveRecord::Migration[7.1]
  def change
    create_table :venues do |t|
      t.string :name
      t.text :address
      t.text :description
      t.integer :capacity
      t.text :contact_info

      t.timestamps
    end
  end
end
