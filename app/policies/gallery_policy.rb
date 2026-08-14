# Single source of truth for "who can do what on this gallery" — the
# controller (before_action gates) and the views (which buttons render)
# both ask the same instance instead of each re-deriving the rule.
class GalleryPolicy
  def initialize(user:, owner:)
    @user = user
    @owner = owner
  end

  # The member who owns this gallery — can upload, edit, delete, batch-tag.
  def owner?
    @user.present? && @user == @owner && @user.member?
  end

  # The owner, or a guest routed here by FindDefaultGalleryOwnerForUser —
  # can view and download, but not mutate anything. A guest's own user_id
  # never has photos (they're routed to the member's gallery instead), so
  # `@user == @owner` alone would miss the gallery guests actually see.
  def viewer?
    @user.present? && default_gallery_owner == @owner
  end

  private

  def default_gallery_owner
    @default_gallery_owner ||= FindDefaultGalleryOwnerForUser.call(user: @user).data
  end
end
