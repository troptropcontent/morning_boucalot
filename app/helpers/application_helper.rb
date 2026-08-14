module ApplicationHelper
  include Pagy::Frontend

  # True when the signed-in visitor is the actual member who owns this
  # gallery — not just a guest who happens to be viewing/favoriting the
  # same URL they'd see if `Current.user == owner` were checked alone.
  def owner_of?(owner)
    authenticated? && Current.user == owner && Current.user.member?
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
end
