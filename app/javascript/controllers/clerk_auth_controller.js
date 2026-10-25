import { Controller } from "@hotwired/stimulus"

// Mounts the Clerk sign-in or sign-up widget.
//
// The widget must be mounted after Turbo renders the page. A window "load"
// listener only fires on a full document load, so it misses Turbo navigation.
// A Stimulus controller connects on both initial load and Turbo page changes.
const CLERK_POLL_INTERVAL_MS = 50
const CLERK_TIMEOUT_MS = 2500

export default class extends Controller {
  static values = { mode: String, redirectUrl: String }

  async connect() {
    const clerk = await this.waitForClerk()
    if (!clerk) return

    await clerk.load()

    if (clerk.user) {
      window.location = this.redirectUrlValue
      return
    }

    this.mount(clerk)
  }

  disconnect() {
    this.element.innerHTML = ""
    delete this.element.dataset.clerkMounted
  }

  mount(clerk) {
    if (this.element.dataset.clerkMounted === "true") return

    if (this.modeValue === "sign_up") {
      clerk.mountSignUp(this.element, { afterSignUpUrl: this.redirectUrlValue })
    } else {
      clerk.mountSignIn(this.element, { afterSignInUrl: this.redirectUrlValue })
    }

    this.element.dataset.clerkMounted = "true"
  }

  // The deferred Clerk script may still be loading when Stimulus connects.
  async waitForClerk() {
    const deadline = Date.now() + CLERK_TIMEOUT_MS

    while (!window.Clerk && Date.now() < deadline) {
      await new Promise((resolve) => setTimeout(resolve, CLERK_POLL_INTERVAL_MS))
    }

    return window.Clerk
  }
}
