module Admin
  class DashboardsController < BaseController
    def show
      # One grouped query answers both metrics the brief asks for; the total is the
      # sum of the groups rather than a second COUNT.
      @counts_by_role = User.group(:role).count
      @total = @counts_by_role.values.sum
    end
  end
end
