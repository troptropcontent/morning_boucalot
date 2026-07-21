class DropFavoriteFromPhotos < ActiveRecord::Migration[8.1]
  def change
    remove_column :photos, :favorite, :boolean, default: false, null: false
  end
end
