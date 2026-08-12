class AddNavigationIndexToPhotos < ActiveRecord::Migration[8.1]
  def change
    add_index :photos, [ :user_id, :taken_at, :created_at ]
  end
end
