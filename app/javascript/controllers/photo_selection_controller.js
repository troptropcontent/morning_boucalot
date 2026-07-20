import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["toolbar", "count"]

  connect() {
    this.selectedIds = new Set()
    this.frameRenderHandler = () => this.#applySelectionState()
    this.element.addEventListener("turbo:frame-render", this.frameRenderHandler)
  }

  disconnect() {
    this.element.removeEventListener("turbo:frame-render", this.frameRenderHandler)
  }

  toggleSelect(event) {
    event.stopPropagation()
    const card = event.currentTarget.closest("[data-photo-id]")
    this.#toggleCard(card)
  }

  openTagModal() {
    document.getElementById("batch-tag-modal").showModal()
  }

  submitTags(event) {
    event.preventDefault()
    const form = event.currentTarget.form
    form.querySelectorAll(".js-photo-id").forEach(el => el.remove())
    this.selectedIds.forEach(id => {
      const input = document.createElement("input")
      input.type = "hidden"
      input.name = "photo_ids[]"
      input.value = id
      input.className = "js-photo-id"
      form.appendChild(input)
    })
    form.requestSubmit()
    document.getElementById("batch-tag-modal").close()
    this.#clearAll()
  }

  cancel() {
    this.#clearAll()
  }

  // Private

  #toggleCard(card) {
    const id = card.dataset.photoId
    const selected = !this.selectedIds.has(id)
    selected ? this.selectedIds.add(id) : this.selectedIds.delete(id)
    this.#setCardVisual(card, selected)
    this.#updateToolbar()
  }

  #setCardVisual(card, selected) {
    const btn = card.querySelector(".select-btn")
    const check = card.querySelector(".select-check")
    const overlay = card.querySelector(".select-overlay")

    if (btn) {
      btn.classList.toggle("bg-primary", selected)
      btn.classList.toggle("border-primary", selected)
      btn.classList.toggle("bg-black/25", !selected)
      btn.classList.toggle("border-white/70", !selected)
      check.classList.toggle("hidden", !selected)
    }
    overlay.classList.toggle("hidden", !selected)
  }

  #updateToolbar() {
    const count = this.selectedIds.size
    this.countTarget.textContent = `${count} photo${count === 1 ? "" : "s"} selected`
    this.toolbarTarget.classList.toggle("hidden", count === 0)
  }

  #clearAll() {
    this.selectedIds.clear()
    this.element.querySelectorAll("[data-photo-id]").forEach(card => {
      this.#setCardVisual(card, false)
    })
    this.#updateToolbar()
  }

  #applySelectionState() {
    this.element.querySelectorAll("[data-photo-id]").forEach(card => {
      this.#setCardVisual(card, this.selectedIds.has(card.dataset.photoId))
    })
  }
}
