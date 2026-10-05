class SessionsController < ApplicationController
  # Clerk renders the actual sign-in/sign-up UI client side; these pages just
  # mount the Clerk components.
  def sign_in
  end

  def sign_up
  end

  # Clerk revokes the session client side; this clears our local session as a
  # fallback and redirects home.
  def destroy
    reset_session
    redirect_to root_path, notice: "Signed out"
  end
end
