class RegistrationsController < ApplicationController
  allow_unauthenticated_access

  def new
    @user = User.new
  end

  def create
    @user = User.new(registration_params)

    if @user.save
      start_new_session_for @user
      redirect_to after_authentication_url, notice: "Welcome to Umanni."
    else
      render :new, status: :unprocessable_content
    end
  end

  private
    # :role is absent by design. Self-registration always produces a plain user, and
    # a crafted role parameter has to be ignored rather than merely unused.
    def registration_params
      params.expect(user: [ :full_name, :email, :password, :password_confirmation ])
    end
end
