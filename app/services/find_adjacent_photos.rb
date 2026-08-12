# Finds the previous/next photo relative to a given photo within an already
# filtered/ordered scope (e.g. `@owner.photos.recent.tagged_with(...)`),
# matching the same order as Photo.recent — without loading every id in the
# scope into memory. Uses SQL row-value comparison (supported by both SQLite
# and Postgres) to jump straight to the neighboring row via a single indexed
# query per direction.
class FindAdjacentPhotos < ApplicationService
  def initialize(photo:, scope:)
    @photo = photo
    @scope = scope
  end

  def call
    { previous_photo: neighbor(">", "ASC"), next_photo: neighbor("<", "DESC") }
  end

  private

  # `previous` is the closest photo more recent than @photo (row-value tuple
  # greater than @photo's), `next` is the closest one older (tuple smaller).
  # Columns are qualified with the photos table since callers may join in
  # other tables (e.g. `tagged_with`) that also have created_at/id columns.
  def neighbor(operator, direction)
    @scope
      .where(
        "(photos.taken_at, photos.created_at, photos.id) #{operator} (?, ?, ?)",
        @photo.taken_at, @photo.created_at, @photo.id
      )
      .reorder(Arel.sql("photos.taken_at #{direction}, photos.created_at #{direction}, photos.id #{direction}"))
      .first
  end
end
