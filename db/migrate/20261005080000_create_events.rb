class CreateEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :events do |t|
      t.string :external_id, null: false
      t.string :title, null: false
      t.text :description
      t.string :url
      t.string :image_url
      t.datetime :starts_at, null: false
      t.datetime :ends_at
      t.string :state
      t.string :event_type
      t.string :organizer_id
      t.string :organizer_name
      t.string :venue
      t.string :city
      t.string :country_code
      t.boolean :availability, null: false, default: false
      t.timestamps
    end

    add_index :events, :external_id, unique: true
    add_index :events, :starts_at
  end
end
