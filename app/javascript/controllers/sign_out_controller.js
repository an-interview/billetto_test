import { Controller } from "@hotwired/stimulus"

// Progressive enhancement for sign out.
//
// The sign-out control is a real DELETE /sign-out form, so it works without
// JavaScript: SessionsController resets the Rails session and redirects.
//
// Clerk holds the browser session when clerk-js is loaded, so the controller
// asks Clerk to revoke that session first. The form submission still runs
// afterwards so the Rails session is cleared and there is one predictable
// navigation, instead of letting Clerk and the browser compete over the
// redirect. `navigate` is overridden with a no-op for that reason; older
// clerk-js builds that ignore the option still end up on the same page.
//
// If Clerk is unavailable or signOut rejects, the form submission is the
// fallback, so sign out never leaves the user stuck on the page.
export default class extends Controller {
  async submit(event) {
    const clerk = window.Clerk

    if (!clerk || typeof clerk.signOut !== "function") return

    event.preventDefault()
    const form = event.target

    try {
      if (typeof clerk.load === "function") await clerk.load()
      await clerk.signOut({ navigate: () => {} })
    } catch (error) {
      console.error("Clerk sign out failed", error)
    }

    form.submit()
  }
}
