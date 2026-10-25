class CreateEventVoteStates < ActiveRecord::Migration[8.1]
  def change
    create_table :event_vote_states do |t|
      t.references :event, null: false, foreign_key: true
      t.string :user_id, null: false
      t.string :direction, null: false
      t.timestamps
    end

    add_index :event_vote_states, [ :event_id, :user_id ], unique: true
    add_check_constraint :event_vote_states,
      "direction IN ('up', 'down')",
      name: "event_vote_states_direction_check"
  end
end
