class AddRotationToPhotos < ActiveRecord::Migration[8.1]
  def change
    add_column :photos, :rotation, :integer, default: 0, null: false
  end
end
