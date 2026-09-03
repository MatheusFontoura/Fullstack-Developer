class ProfilesController < ApplicationController
  before_action :set_profile

  def show
  end

  def edit
  end

  def update
    if @user.update(profile_params)
      redirect_to profile_path, notice: "Your profile was updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @user.destroy!
    terminate_session
    redirect_to new_session_path, notice: "Your account has been deleted.", status: :see_other
  end

  private
    # Always the signed-in user. There is no id in the route, so there is nothing to
    # tamper with: a user cannot ask for someone else's profile by changing a number.
    def set_profile
      @user = Current.user
    end

    # :role is absent, as it is everywhere outside the admin namespace. A user editing
    # their own profile cannot promote themselves.
    def profile_params
      permitted = params.expect(user: [ :full_name, :email, :password, :password_confirmation, :avatar_image ])
      permitted = permitted.except(:password, :password_confirmation) if permitted[:password].blank?
      permitted = permitted.except(:avatar_image) if permitted[:avatar_image].blank?
      permitted
    end
end
