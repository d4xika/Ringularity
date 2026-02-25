class CreateHrvLogsTable < ActiveRecord::Migration[8.1]
  def change
    create_table :hrv_logs do |t|
      t.timestamps
      t.datetime :recorded_at
      t.integer :hrv_val
      t.references :user, null: false, foreign_key: true

      t.index [:recorded_at, :user_id], unique: true, name: 'unique_hrv_logs'
    end
  end
end
