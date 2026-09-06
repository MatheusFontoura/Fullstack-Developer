class PasswordsController < ApplicationController
  allow_unauthenticated_access
  before_action :set_user_by_token, only: %i[ edit update ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_password_path, alert: "Try again later." }

  def new
  end

  def create
    if (user = User.find_by(email: reset_request_params[:email]))
      PasswordsMailer.reset(user).deliver_later
    end

    redirect_to new_session_path, notice: "If that email address has an account, reset instructions are on the way."
  end

  def edit
  end

  def update
    if @user.update(new_password_params)
      @user.sessions.destroy_all
      redirect_to new_session_path, notice: "Password has been reset."
    else
      # The generated controller reports "passwords did not match" for every failure,
      # which is wrong as soon as there is a length rule to break.
      flash.now[:alert] = @user.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_content
    end
  end

  private
    def reset_request_params
      params.expect(password_reset: [ :email ])
    end

    def new_password_params
      params.expect(password_reset: [ :password, :password_confirmation ])
    end

    def set_user_by_token
      @user = User.find_by_password_reset_token!(params[:token])
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      redirect_to new_password_path, alert: "Password reset link is invalid or has expired."
    end
end
