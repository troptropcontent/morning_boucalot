class AddPublishedToPhotos < ActiveRecord::Migration[8.1]
  def change
    add_column :photos, :published, :boolean, null: false, default: true
    add_index :photos, [ :user_id, :published ]
  end
end
