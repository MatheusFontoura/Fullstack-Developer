module Admin
  class UsersController < BaseController
    before_action :set_user, only: %i[ edit update destroy ]

    def index
      # request.query_parameters here would let ?host= rewrite the links.
      @filters = params.permit(:query, :role, :page).to_h.compact_blank.except("page")
      @page = Pagination.new(filtered_users.ordered, page: params[:page])
    end

    def new
      @user = User.new
    end

    def create
      @user = User.new(user_params)

      if @user.save
        redirect_to admin_users_path, notice: "#{@user.full_name} was added."
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
    end

    def update
      if @user.update(user_params)
        redirect_to admin_users_path, notice: "#{@user.full_name} was updated."
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      if @user == Current.user
        redirect_to admin_users_path, alert: "Delete your own account from your profile."
      else
        @user.destroy!
        redirect_to admin_users_path, notice: "#{@user.full_name} was removed.", status: :see_other
      end
    end

    private
      def set_user
        @user = User.find(params[:id])
      end

      # The only place :role is permitted, and not for yourself.
      def user_params
        permitted = without_untouched_fields params.expect(
          user: [ :full_name, :email, :role, :password, :password_confirmation, :avatar_image, :remove_avatar_image ]
        )
        @user == Current.user ? permitted.except(:role) : permitted
      end

      def filtered_users
        # Without the eager load this costs one attachment query per row rendered.
        scope = User.with_attached_avatar_image
        scope = scope.matching(params[:query]) if params[:query].present?
        # Checked against the enum rather than passed through, so a crafted role
        # parameter cannot reach the query.
        scope = scope.where(role: params[:role]) if User.roles.key?(params[:role])
        scope
      end
  end
end
