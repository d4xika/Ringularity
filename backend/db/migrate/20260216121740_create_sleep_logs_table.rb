class CreateSleepLogsTable < ActiveRecord::Migration[8.1]
  def change
    create_table :sleep_logs do |t|
      t.timestamps
      t.datetime :recorded_at
      t.integer :sleep_stage
      t.integer :duration_minutes
      t.references :user, null: false, foreign_key: true

      t.index [:recorded_at, :user_id], unique: true, name: 'unique_sleep_logs'
    end
  end
end
