class AddStatusToPhotos < ActiveRecord::Migration[8.1]
  def up
    add_column :photos, :status, :string, null: false, default: "pending"
    Photo.update_all(status: "ready")
  end

  def down
    remove_column :photos, :status
  end
end
