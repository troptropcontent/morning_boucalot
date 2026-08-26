
import { Controller } from "@hotwired/stimulus"

// Client-side search over the tag picker's pill list. All tags are already
// server-rendered (one query per index request), so filtering as-you-type
// is just show/hide — no round trip needed unless the tag count grows into
// the thousands, at which point this should move server-side instead.
export default class extends Controller {
  static targets = ["search", "pill", "empty"]

  filter() {
    const query = this.searchTarget.value.trim().toLowerCase()
    let visibleCount = 0

    this.pillTargets.forEach((pill) => {
      const matches = pill.textContent.trim().toLowerCase().includes(query)
      pill.classList.toggle("hidden", !matches)
      if (matches) visibleCount++
    })

    this.emptyTarget.classList.toggle("hidden", visibleCount > 0)
  }
}
