class CreatePhotos < ActiveRecord::Migration[8.1]
  def change
    create_table :photos do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title
      t.text :description
      t.datetime :taken_at
      t.string :camera_model
      t.decimal :focal_length, precision: 8, scale: 2
      t.decimal :aperture, precision: 5, scale: 2
      t.integer :iso
      t.string :shutter_speed
      t.integer :width
      t.integer :height
      t.integer :file_size

      t.timestamps
    end
  end
end
