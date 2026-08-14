# Single source of truth for what the current tag/favorited filter means —
# resolved once per request instead of the controller and every view each
# re-deriving whether params[:favorited] is actually in effect.
class PhotoFilter
  attr_reader :tag

  def initialize(params:, user:)
    @tag = params[:tag].presence
    @user = user
    @favorited_requested = params[:favorited].present?
  end

  # Favoriting is per-user: without a signed-in user there's nothing to
  # scope by, so the filter is never actually active even if the param is
  # present (e.g. a stale link left over from before signing out).
  def favorited?
    @favorited_requested && favoritable?
  end

  # Whether "favorited" is a meaningful filter at all right now — false for
  # an anonymous visitor, regardless of what the param says. Drives whether
  # the toggle itself should even be shown.
  def favoritable?
    @user.present?
  end

  def apply(photos)
    photos = photos.tagged_with(tag) if tag
    favorited? ? photos.favorited_by(@user) : photos
  end

  # For propagating the current filter into other links (adjacent photo,
  # back-to-gallery, …) without each view re-reading raw params.
  def to_params
    { tag: tag, favorited: favorited? ? 1 : nil }
  end

  # Same tag, opposite favorited state — for the toggle button.
  def toggled_params
    { tag: tag, favorited: favorited? ? nil : 1 }
  end
end
