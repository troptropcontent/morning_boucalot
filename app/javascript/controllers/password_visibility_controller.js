import { Controller } from "@hotwired/stimulus"

// Toggles a password field between masked and plain text.
export default class extends Controller {
  static targets = ["input", "button"]

  toggle() {
    const showing = this.inputTarget.type === "text"

    this.inputTarget.type = showing ? "password" : "text"
    this.buttonTarget.textContent = showing ? "Show" : "Hide"
    this.buttonTarget.setAttribute("aria-label", showing ? "Show password" : "Hide password")
    this.buttonTarget.setAttribute("aria-pressed", String(!showing))
  }
}
