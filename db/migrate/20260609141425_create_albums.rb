class CreateAlbums < ActiveRecord::Migration[8.1]
  def change
    create_table :albums do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title
      t.text :description
      t.integer :cover_photo_id

      t.timestamps
    end
    add_index :albums, :title
  end
end
