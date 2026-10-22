class AddStraightenAngleToPhotos < ActiveRecord::Migration[8.1]
  # Degrees, clockwise, applied on top of the quarter-turn `rotation`.
  def change
    add_column :photos, :straighten_angle, :decimal, precision: 4, scale: 2, null: false, default: 0
  end
end
