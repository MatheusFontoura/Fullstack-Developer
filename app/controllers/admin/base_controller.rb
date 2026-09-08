module Admin
  class BaseController < ApplicationController
    before_action :require_admin

    private
      def require_admin
        redirect_to profile_url, alert: "You are not authorised to access that page." unless Current.user.admin?
      end
  end
end
