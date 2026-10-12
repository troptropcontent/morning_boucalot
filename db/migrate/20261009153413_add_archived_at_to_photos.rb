class AddArchivedAtToPhotos < ActiveRecord::Migration[8.1]
  def change
    add_column :photos, :archived_at, :datetime
    add_index :photos, [ :user_id, :archived_at ]
  end
end
