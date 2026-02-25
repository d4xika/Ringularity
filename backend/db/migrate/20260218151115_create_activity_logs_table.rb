class CreateActivityLogsTable < ActiveRecord::Migration[8.1]
  def change
    create_table :activity_logs do |t|
      t.timestamps
      t.string :type
      t.string :custom_title
      t.datetime :recorded_at
      t.integer :duration
      t.float :distance
      t.integer :avg_heart_rate
      t.integer :steps
      t.integer :hr_trace, array: true, default: []
      t.jsonb :route, default: []
      t.references :user, null: false, foreign_key: true

      t.index [:recorded_at, :user_id], unique: true, name: 'unique_activity_logs'
    end
  end
end
