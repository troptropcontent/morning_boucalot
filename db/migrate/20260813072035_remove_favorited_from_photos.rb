class RemoveFavoritedFromPhotos < ActiveRecord::Migration[8.1]
  def change
    # Favorites moved to the `favorites` join table (per-user) in the
    # preceding CreateFavorites migration, which backfills from this column.
    remove_column :photos, :favorited, :boolean, default: false, null: false
  end
end
