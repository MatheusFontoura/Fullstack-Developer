import { Controller } from "@hotwired/stimulus"

// Keeps a form from being submitted twice and says so while the request is in flight.
// Turbo already prevents the double navigation, but the button stays enabled and
// unchanged, so on a slow request there is nothing telling anyone the click landed.
export default class extends Controller {
  static targets = ["submit"]
  static values = { submitting: { type: String, default: "Working…" } }

  connect() {
    this.originalLabel = this.submitTarget.value
  }

  // Turbo re-enables the button itself when the response renders, so a validation
  // error leaves the form usable without any reset of our own.
  submitting() {
    this.submitTarget.disabled = true
    this.submitTarget.value = this.submittingValue
  }
}
