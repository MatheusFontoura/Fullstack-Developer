module Admin
  class UsersController < BaseController
    before_action :set_user, only: %i[ edit update destroy ]

    def index
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

      # Role is permitted here and nowhere else: an admin assigns roles, a visitor
      # registering themselves does not.
      def user_params
        permitted = params.expect(
          user: [ :full_name, :email, :role, :password, :password_confirmation, :avatar_image ]
        )

        # An edit form submits both fields empty when the admin is not changing the
        # password, and an empty file input submits a blank avatar. Blanking those keys
        # rather than compacting the whole hash keeps "the admin cleared the name" a
        # validation error instead of a silent no-op.
        permitted = permitted.except(:password, :password_confirmation) if permitted[:password].blank?
        permitted = permitted.except(:avatar_image) if permitted[:avatar_image].blank?
        permitted
      end

      def filtered_users
        scope = User.all
        scope = scope.search(params[:query]) if params[:query].present?
        # Checked against the enum rather than passed through, so a crafted role
        # parameter cannot reach the query.
        scope = scope.with_role(params[:role]) if User.roles.key?(params[:role])
        scope
      end
  end
end
