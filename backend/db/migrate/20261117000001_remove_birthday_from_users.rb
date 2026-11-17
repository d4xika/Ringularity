class RemoveBirthdayFromUsers < ActiveRecord::Migration[8.1]
  def change
    remove_column :users, :birthday, :date
  end
end
