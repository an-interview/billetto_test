import { Controller } from "@hotwired/stimulus"

// Mounts the Clerk sign-in or sign-up widget.
//
// The widget must be mounted after Turbo renders the page. A window "load"
// listener only fires on a full document load, so it misses Turbo navigation.
// A Stimulus controller connects on both initial load and Turbo page changes.
//
// Clerk's current component props use fallbackRedirectUrl / forceRedirectUrl,
// not the older afterSignInUrl / afterSignUpUrl props. The auth-state listener
// is a fallback for flows where the widget completes without a redirect.
const CLERK_POLL_INTERVAL_MS = 50
const CLERK_TIMEOUT_MS = 2500

export default class extends Controller {
  static values = { mode: String, redirectUrl: String }

  async connect() {
    const clerk = await this.waitForClerk()
    if (!clerk) return

    await clerk.load()
    this.subscribe(clerk)

    if (clerk.user) {
      this.redirect()
      return
    }

    this.mount(clerk)
  }

  disconnect() {
    if (this.unsubscribe) {
      this.unsubscribe()
      this.unsubscribe = null
    }

    this.redirected = false
    this.unmount()
  }

  subscribe(clerk) {
    if (this.unsubscribe || typeof clerk.addListener !== "function") return

    this.unsubscribe = clerk.addListener(({ user }) => {
      if (user) this.redirect()
    })
  }

  redirect() {
    if (this.redirected) return

    this.redirected = true
    window.location.assign(this.redirectUrlValue || "/")
  }

  mount(clerk) {
    if (this.element.dataset.clerkMounted === "true") return

    const options = { fallbackRedirectUrl: this.redirectUrlValue }

    if (this.modeValue === "sign_up") {
      clerk.mountSignUp(this.element, options)
    } else {
      clerk.mountSignIn(this.element, options)
    }

    this.element.dataset.clerkMounted = "true"
  }

  unmount() {
    const clerk = window.Clerk

    if (clerk) {
      if (this.modeValue === "sign_up") {
        clerk.unmountSignUp?.(this.element)
      } else {
        clerk.unmountSignIn?.(this.element)
      }
    }

    this.element.innerHTML = ""
    delete this.element.dataset.clerkMounted
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
