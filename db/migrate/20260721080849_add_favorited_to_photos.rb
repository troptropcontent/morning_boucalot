class AddFavoritedToPhotos < ActiveRecord::Migration[8.1]
  def change
    add_column :photos, :favorited, :boolean, default: false, null: false
    remove_column :photos, :favorite, :boolean, default: false, null: false
  end
end
