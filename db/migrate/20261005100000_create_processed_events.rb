class CreateProcessedEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :processed_events do |t|
      t.string :handler, null: false
      t.string :event_id, null: false
      t.timestamps
    end

    add_index :processed_events, [ :handler, :event_id ], unique: true
  end
end
