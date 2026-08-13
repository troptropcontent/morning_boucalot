class CreateFavorites < ActiveRecord::Migration[8.1]
  def change
    create_table :favorites do |t|
      t.references :user, null: false, foreign_key: true
      t.references :photo, null: false, foreign_key: true

      t.timestamps
    end

    add_index :favorites, [ :user_id, :photo_id ], unique: true

    # Backfill: photos previously flagged `favorited` become a favorite owned
    # by the photo's own user, so nobody loses their existing favorites.
    reversible do |dir|
      dir.up do
        execute <<~SQL
          INSERT INTO favorites (user_id, photo_id, created_at, updated_at)
          SELECT user_id, id, created_at, updated_at FROM photos WHERE favorited = TRUE
        SQL
      end
    end
  end
end
