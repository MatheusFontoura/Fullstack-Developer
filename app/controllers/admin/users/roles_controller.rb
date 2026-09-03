module Admin
  module Users
    class RolesController < BaseController
      before_action :set_user

      def update
        if @user == Current.user
          return redirect_to admin_users_path,
                             alert: "You cannot change your own role. Ask another admin."
        end

        @user.update!(role: @user.admin? ? :user : :admin)
        message = "#{@user.full_name} is now #{@user.admin? ? "an admin" : "a user"}."

        respond_to do |format|
          format.turbo_stream { flash.now[:notice] = message }
          format.html { redirect_to admin_users_path, notice: message }
        end
      end

      private
        def set_user
          @user = User.find(params[:user_id])
        end
    end
  end
end
