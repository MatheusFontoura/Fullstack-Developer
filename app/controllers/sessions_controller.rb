class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create,
             with: -> { redirect_to new_session_path, alert: "Too many attempts. Try again later." }

  def new
  end

  def create
    if (user = authenticate)
      start_new_session_for user
      redirect_to after_authentication_url
    else
      flash.now[:alert] = "Try another email address or password."
      render :new, status: :unprocessable_content
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path, status: :see_other
  end

  private
    # expect, not permit: a login attempt has exactly one shape, and anything else is
    # a malformed request rather than a wrong password.
    # expect guarantees the envelope, not that the fields inside it are filled, and
    # authenticate_by raises on a missing one. A half-filled form is a failed login.
    def authenticate
      credentials = params.expect(session: [ :email, :password ])
      return if credentials[:email].blank? || credentials[:password].blank?

      User.authenticate_by(credentials)
    end
end
