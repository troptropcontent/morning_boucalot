import { Controller } from "@hotwired/stimulus"

// Warms the browser's image cache with the next photo's large variant while
// the current one is being viewed, so tapping "next" feels instant instead
// of waiting on a cold fetch.
export default class extends Controller {
  static values = { url: String }

  connect() {
    if (!this.hasUrlValue || !this.urlValue) return

    const image = new Image()
    image.src = this.urlValue
  }
}
