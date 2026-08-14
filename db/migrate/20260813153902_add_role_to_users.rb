class AddRoleToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :role, :string, default: "member", null: false

    # Guests never have a password — they authenticate via emailed OTP.
    change_column_null :users, :password_digest, true
  end
end
