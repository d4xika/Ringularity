class AddAuthKeyToUser < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :auth_key, :string
  end
end
