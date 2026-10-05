import { Controller } from "@hotwired/stimulus"

// Progressive enhancement for sign out.
//
// The sign-out control is a real form (DELETE /sign-out), so it works without
// JavaScript. When Clerk is loaded it holds the actual session, so we revoke it
// and let Clerk redirect; otherwise the form submits and SessionsController
// resets the Rails session.
export default class extends Controller {
  static values = { redirectUrl: String }

  submit(event) {
    if (!window.Clerk) return

    event.preventDefault()
    window.Clerk.signOut({ redirectUrl: this.redirectUrlValue })
  }
}
