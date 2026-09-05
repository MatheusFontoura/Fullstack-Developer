module Admin
  # Every admin screen inherits from here, so authorisation is a property of the
  # namespace rather than something each controller has to remember to declare.
  class BaseController < ApplicationController
    before_action :require_admin

    private
      def require_admin
        redirect_to profile_url, alert: "You are not authorised to access that page." unless Current.user.admin?
      end
  end
end
