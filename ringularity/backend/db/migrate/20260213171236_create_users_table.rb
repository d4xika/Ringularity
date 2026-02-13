class CreateUsersTable < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :email
      t.string :name
      t.date :birthday
      t.string :password
      t.timestamps
    end
  end
end
