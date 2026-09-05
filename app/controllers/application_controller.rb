class ApplicationController < ActionController::Base
  include Authentication

  # Rejects browsers without webp, import maps, CSS nesting and CSS :has. That covers
  # every current Chrome, Safari, Firefox and Edge; it excludes IE and long-abandoned
  # builds. Turbo and Stimulus degrade gracefully within that range, so no polyfills.
  allow_browser versions: :modern

  stale_when_importmap_changes

  private
    # Honours a deep link the visitor was bounced away from, and otherwise sends each
    # role to the screen the brief specifies as their landing page.
    def after_authentication_url
      session.delete(:return_to_after_authenticating) || home_url_for(Current.user)
    end

    def home_url_for(user)
      user.admin? ? admin_dashboard_url : profile_url
    end
end
