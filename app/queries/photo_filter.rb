# Single source of truth for what the current tag/favorited filter means —
# resolved once per request instead of the controller and every view each
# re-deriving whether params[:favorited] is actually in effect.
class PhotoFilter
  attr_reader :tag, :page

  def initialize(params:, user:)
    @tag = params[:tag].presence
    @page = params[:page].presence
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
  # back-to-gallery, …) without each view re-reading raw params. Carries the
  # page along too, so "back to photos" from a detail page returns to the
  # index page it was reached from, not always page 1.
  def to_params
    { tag: tag, favorited: favorited? ? 1 : nil, page: page }
  end

  # Same tag, opposite favorited state — for the toggle button. Deliberately
  # drops the page: switching filters changes the result set, so landing on
  # page 1 of it makes more sense than staying on whatever page number was
  # showing before.
  def toggled_params
    { tag: tag, favorited: favorited? ? nil : 1 }
  end
end
