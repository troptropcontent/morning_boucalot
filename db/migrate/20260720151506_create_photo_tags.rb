class CreatePhotoTags < ActiveRecord::Migration[8.1]
  def change
    create_table :photo_tags do |t|
      t.references :photo, null: false, foreign_key: true
      t.references :tag, null: false, foreign_key: true

      t.timestamps
    end
    add_index :photo_tags, [ :photo_id, :tag_id ], unique: true
  end
end
