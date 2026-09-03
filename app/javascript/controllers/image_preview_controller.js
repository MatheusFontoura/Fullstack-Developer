import { Controller } from "@hotwired/stimulus"

// Shows the picked image before it is uploaded. Nothing in Turbo covers this: it reads
// a File the browser already has, with no request involved.
export default class extends Controller {
  static targets = ["input", "preview", "current"]

  show() {
    const [file] = this.inputTarget.files
    if (!file) return

    this.#releaseUrl()
    this.url = URL.createObjectURL(file)
    this.previewTarget.src = this.url
    this.previewTarget.hidden = false
    this.currentTarget.hidden = true
  }

  // An object URL pins the file in memory until it is revoked, and Turbo caches pages
  // rather than reloading them, so without this the leak survives navigation.
  disconnect() {
    this.#releaseUrl()
  }

  #releaseUrl() {
    if (this.url) URL.revokeObjectURL(this.url)
    this.url = null
  }
}
