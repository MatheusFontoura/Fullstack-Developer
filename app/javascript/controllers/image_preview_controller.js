import { Controller } from "@hotwired/stimulus"

// Shows the picked image before it is uploaded. Nothing in Turbo covers this: it reads
// a File the browser already has, with no request involved.
export default class extends Controller {
  static targets = ["input", "preview", "current"]

  show() {
    const [file] = this.inputTarget.files
    this.#releaseUrl()

    // Picker cancelled after a previous choice: go back to what is actually stored.
    if (!file) return this.#showCurrent()

    this.url = URL.createObjectURL(file)
    this.previewTarget.src = this.url
    this.previewTarget.hidden = false
    this.currentTarget.hidden = true
  }

  // An object URL pins the file until revoked, and Turbo restores cached pages rather
  // than reloading them — so the preview is torn down here as well, or a restored page
  // shows an <img> pointing at a URL that no longer resolves.
  disconnect() {
    this.#releaseUrl()
    this.#showCurrent()
  }

  #showCurrent() {
    this.previewTarget.hidden = true
    this.previewTarget.removeAttribute("src")
    this.currentTarget.hidden = false
  }

  #releaseUrl() {
    if (this.url) URL.revokeObjectURL(this.url)
    this.url = null
  }
}
