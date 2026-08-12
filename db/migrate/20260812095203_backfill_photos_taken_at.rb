class BackfillPhotosTakenAt < ActiveRecord::Migration[8.1]
  def up
    execute "UPDATE photos SET taken_at = created_at WHERE taken_at IS NULL"
    change_column_null :photos, :taken_at, false
  end

  def down
    change_column_null :photos, :taken_at, true
  end
end
