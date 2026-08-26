import { Controller } from "@hotwired/stimulus"

// Chip-style tag entry: committed tags render as removable pills and stay
// in sync with a hidden comma-separated field (the one actually submitted).
// The visible field only ever holds one in-progress tag at a time, so the
// browser's native <datalist> suggestions work normally — no reimplementing
// autocomplete by hand.
export default class extends Controller {
  static targets = ["hidden", "chips", "entry"]

  connect() {
    this.tags = this.hiddenTarget.value.split(",").map((t) => t.trim()).filter(Boolean)
    this.#render()
  }

  keydown(event) {
    if (event.key === "Enter" || event.key === ",") {
      event.preventDefault()
      this.#commit(this.entryTarget.value)
    } else if (event.key === "Backspace" && this.entryTarget.value === "") {
      this.tags.pop()
      this.#sync()
    }
  }

  // Fires on datalist selection (change) and on leaving the field (blur) —
  // either way, whatever's sitting in the entry field should become a chip
  // instead of being silently lost.
  commitPending() {
    this.#commit(this.entryTarget.value)
  }

  remove(event) {
    const tag = event.currentTarget.dataset.tag
    this.tags = this.tags.filter((t) => t !== tag)
    this.#sync()
  }

  #commit(raw) {
    const name = raw.trim().replace(/,$/, "").toLowerCase()
    this.entryTarget.value = ""
    if (!name || this.tags.includes(name)) return

    this.tags.push(name)
    this.#sync()
  }

  #sync() {
    this.hiddenTarget.value = this.tags.join(", ")
    this.#render()
  }

  // Built via the DOM API rather than innerHTML — tag names are
  // user-supplied text and must never be interpreted as markup.
  #render() {
    this.chipsTarget.innerHTML = ""

    this.tags.forEach((tag) => {
      const chip = document.createElement("span")
      chip.className = "badge badge-outline gap-1"
      chip.append(document.createTextNode(tag))

      const remove = document.createElement("button")
      remove.type = "button"
      remove.className = "leading-none"
      remove.setAttribute("aria-label", `Remove ${tag}`)
      remove.dataset.action = "click->tag-input#remove"
      remove.dataset.tag = tag
      remove.textContent = "✕"
      chip.append(remove)

      this.chipsTarget.append(chip)
    })
  }
}
