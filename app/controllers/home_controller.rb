# The root path has no screen of its own: admins belong on the dashboard, everyone
# else on their profile. Keeping that decision here means a bookmarked "/" behaves
# the same as a fresh login.
class HomeController < ApplicationController
  def show
    redirect_to home_url_for(Current.user)
  end
end
