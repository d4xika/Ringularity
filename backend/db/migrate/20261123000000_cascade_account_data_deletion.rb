class CascadeAccountDataDeletion < ActiveRecord::Migration[8.1]
  TABLES = %i[activity_logs heart_rate_logs hrv_logs sleep_logs steps_logs stress_logs].freeze

  def up
    TABLES.each do |table|
      remove_foreign_key table, :users
      add_foreign_key table, :users, on_delete: :cascade
    end
  end

  def down
    TABLES.each do |table|
      remove_foreign_key table, :users
      add_foreign_key table, :users
    end
  end
end
