class CreateStressLogsTable < ActiveRecord::Migration[8.1]
  def change
    create_table :stress_logs do |t|
      t.timestamps
      t.datetime :recorded_at
      t.integer :stress_level
      t.string :device_id
      t.references :user, null: false, foreign_key: true

      t.index [:device_id, :recorded_at, :user_id], unique: true, name: 'unique_stress_logs'
    end
  end
end
