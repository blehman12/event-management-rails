class CreateVenues < ActiveRecord::Migration[7.1]
  def change
    return if table_exists?(:venues)
    
    create_table :venues do |t|
      t.string :name, null: false
      t.text :address
      t.text :description
      t.integer :capacity
      t.text :amenities
      t.string :contact_email
      t.string :contact_phone
      
      t.timestamps
    end
    
    add_index :venues, :name
  end
end
