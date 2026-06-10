class DropAlbums < ActiveRecord::Migration[8.1]
  def change
    drop_table :album_photos do |t|
      t.references :album, null: false, foreign_key: true
      t.references :photo, null: false, foreign_key: true
      t.timestamps
    end

    drop_table :albums do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title, null: false
      t.text :description
      t.integer :cover_photo_id
      t.timestamps
    end
  end
end
