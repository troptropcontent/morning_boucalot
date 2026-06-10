import { Controller } from "@hotwired/stimulus"

const STATUS = {
  queued:    { label: "Queued",      css: "badge-neutral" },
  uploading: { label: "Uploading…",  css: "badge-warning" },
  done:      { label: "Done",        css: "badge-success" },
  failed:    { label: "Failed",      css: "badge-error"   },
}

export default class extends Controller {
  static targets = ["input", "dropzone", "queue", "summary", "summaryText"]

  connect() {
    this.files = []
    this.processing = false
  }

  filesSelected(event) {
    this.enqueue(Array.from(event.target.files))
    event.target.value = ""
  }

  dragover(event) {
    event.preventDefault()
    this.dropzoneTarget.classList.add("border-primary", "bg-primary/5")
  }

  dragleave() {
    this.dropzoneTarget.classList.remove("border-primary", "bg-primary/5")
  }

  drop(event) {
    event.preventDefault()
    this.dropzoneTarget.classList.remove("border-primary", "bg-primary/5")
    const images = Array.from(event.dataTransfer.files).filter(f => f.type.startsWith("image/"))
    this.enqueue(images)
  }

  enqueue(newFiles) {
    newFiles.forEach(file => {
      const entry = { id: crypto.randomUUID(), file, status: "queued" }
      this.files.push(entry)
      this.renderCard(entry)
    })
    this.processNext()
  }

  renderCard(entry) {
    const card = document.createElement("div")
    card.dataset.fileId = entry.id
    card.className = "relative rounded-lg overflow-hidden bg-base-200 aspect-square"
    card.innerHTML = `
      <img class="w-full h-full object-cover" data-preview />
      <div class="absolute bottom-0 inset-x-0 bg-gradient-to-t from-black/60 to-transparent p-2">
        <span class="badge badge-sm badge-neutral" data-status>Queued</span>
        <p class="text-white text-xs truncate mt-1" data-filename></p>
      </div>
    `
    card.querySelector("[data-filename]").textContent = entry.file.name

    const reader = new FileReader()
    reader.onload = e => { card.querySelector("[data-preview]").src = e.target.result }
    reader.readAsDataURL(entry.file)

    this.queueTarget.appendChild(card)
  }

  updateCard(id, status) {
    const card = this.queueTarget.querySelector(`[data-file-id="${id}"]`)
    if (!card) return
    const badge = card.querySelector("[data-status]")
    const { label, css } = STATUS[status]
    badge.textContent = label
    badge.className = `badge badge-sm ${css}`
  }

  async processNext() {
    if (this.processing) return
    this.processing = true

    let entry
    while ((entry = this.files.find(e => e.status === "queued"))) {
      entry.status = "uploading"
      this.updateCard(entry.id, "uploading")
      try {
        await this.upload(entry.file)
        entry.status = "done"
        this.updateCard(entry.id, "done")
      } catch {
        entry.status = "failed"
        this.updateCard(entry.id, "failed")
      }
    }

    this.processing = false
    this.checkAllDone()
  }

  async upload(file) {
    const formData = new FormData()
    formData.append("photo[file]", file)
    const response = await fetch("/photos.json", {
      method: "POST",
      headers: { "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content },
      body: formData,
    })
    if (!response.ok) throw new Error("Upload failed")
  }

  checkAllDone() {
    if (this.files.length === 0) return
    const allSettled = this.files.every(e => e.status === "done" || e.status === "failed")
    if (!allSettled) return

    const done = this.files.filter(e => e.status === "done").length
    const failed = this.files.filter(e => e.status === "failed").length
    const parts = []
    if (done > 0) parts.push(`${done} photo${done > 1 ? "s" : ""} uploaded`)
    if (failed > 0) parts.push(`${failed} failed`)
    this.summaryTextTarget.textContent = parts.join(", ")
    this.summaryTarget.classList.remove("hidden")
  }
}
