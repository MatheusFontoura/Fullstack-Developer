class RegistrationsController < ApplicationController
  allow_unauthenticated_access
  before_action :redirect_if_authenticated, only: :new
  rate_limit to: 10, within: 3.minutes, only: :create,
             with: -> { redirect_to new_registration_path, alert: "Too many attempts. Try again later." }

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
    def registration_params
      params.expect(user: [ :full_name, :email, :password, :password_confirmation ])
    end
end
