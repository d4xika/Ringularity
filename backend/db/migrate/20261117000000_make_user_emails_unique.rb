class MakeUserEmailsUnique < ActiveRecord::Migration[8.1]
  def up
    execute "LOCK TABLE users IN SHARE ROW EXCLUSIVE MODE"

    duplicates = select_values(<<~SQL)
      SELECT string_agg(id::text, ', ' ORDER BY id)
      FROM users
      WHERE email IS NOT NULL
      GROUP BY LOWER(BTRIM(email))
      HAVING COUNT(*) > 1
    SQL

    if duplicates.any?
      raise ActiveRecord::MigrationError,
        "Resolve duplicate emails for these user ID groups before migrating: #{duplicates.join('; ')}"
    end

    execute "UPDATE users SET email = LOWER(BTRIM(email)) WHERE email IS NOT NULL"
    add_index :users, "LOWER(BTRIM(email))", unique: true, name: "index_users_on_normalized_email"
  end

  def down
    remove_index :users, name: "index_users_on_normalized_email"
  end
end
