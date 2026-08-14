module ApplicationHelper
  include Pagy::Frontend

  # True when the signed-in visitor is the actual member who owns this
  # gallery — not just a guest who happens to be viewing/favoriting the
  # same URL they'd see if `Current.user == owner` were checked alone.
  def owner_of?(owner)
    authenticated? && Current.user == owner && Current.user.member?
  end

  # True when the signed-in visitor belongs on this gallery — the member on
  # their own gallery, or a guest on the gallery they were routed to by
  # FindDefaultGalleryOwnerForUser (their own user_id never has photos, so
  # `Current.user == owner` alone would miss the gallery guests actually
  # see). Unlike owner_of?, doesn't require Current.user.member?: guests may
  # view/download here, just not edit.
  def gallery_viewer?(owner)
    authenticated? && default_gallery_owner_for_current_user == owner
  end

  def pagy_nav(pagy, **vars)
    p_prev  = pagy.prev
    p_next  = pagy.next
    p_pages = pagy.pages

    html = +'<div class="join">'

    html << if p_prev
              %(<a class="join-item btn btn-sm" href="#{pagy_url_for(pagy, p_prev)}" aria-label="Previous">«</a>)
            else
              %(<button class="join-item btn btn-sm btn-disabled" aria-disabled="true">«</button>)
            end

    pagy.series(**vars).each do |item|
      html << case item
              when Integer
                %(<a class="join-item btn btn-sm" href="#{pagy_url_for(pagy, item)}">#{item}</a>)
              when String
                %(<button class="join-item btn btn-sm btn-active" aria-current="page">#{item}</button>)
              when :gap
                %(<button class="join-item btn btn-sm btn-disabled">…</button>)
              end
    end

    html << if p_next
              %(<a class="join-item btn btn-sm" href="#{pagy_url_for(pagy, p_next)}" aria-label="Next">»</a>)
            else
              %(<button class="join-item btn btn-sm btn-disabled" aria-disabled="true">»</button>)
            end

    html << "</div>"
    html.html_safe
  end

  private

  # Memoized per render — for a guest this issues a query
  # (User.member.first), and gallery_viewer? is called once per photo card.
  def default_gallery_owner_for_current_user
    @default_gallery_owner_for_current_user ||= FindDefaultGalleryOwnerForUser.call(user: Current.user).data
  end
end
