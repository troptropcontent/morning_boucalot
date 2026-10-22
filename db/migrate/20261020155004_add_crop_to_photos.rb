class AddCropToPhotos < ActiveRecord::Migration[8.1]
  # Fractions (0..1) of the rotated image rather than pixels, so the crop
  # doesn't depend on which resolution the user drew it on.
  def change
    add_column :photos, :crop_x, :decimal, precision: 7, scale: 6
    add_column :photos, :crop_y, :decimal, precision: 7, scale: 6
    add_column :photos, :crop_w, :decimal, precision: 7, scale: 6
    add_column :photos, :crop_h, :decimal, precision: 7, scale: 6
  end
end
