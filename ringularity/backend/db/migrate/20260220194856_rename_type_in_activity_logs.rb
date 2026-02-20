class RenameTypeInActivityLogs < ActiveRecord::Migration[8.1]
  def change
    rename_column :activity_logs, :type, :activity_type
  end
end
