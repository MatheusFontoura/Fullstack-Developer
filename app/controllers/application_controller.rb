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

    def uploaded_file
      ActionDispatch::Http::UploadedFile
    end

    def home_url_for(user)
      user.admin? ? admin_dashboard_url : profile_url
    end

    # An edit form submits empty password fields when the password is not being
    # changed, and an empty file input when no new avatar was picked. Dropping those
    # keys is what keeps "I did not touch this" from being read as "clear it", while
    # still letting a genuinely cleared name fail validation instead of passing
    # silently — which is why this is not a blanket compact_blank.
    def without_untouched_fields(permitted)
      permitted = permitted.except(:password, :password_confirmation) if permitted[:password].blank?
      # Anything that is not an upload — a blank input, or a string a client invented —
      # is dropped: Active Storage reads a string as a signed id and raises on it.
      permitted = permitted.except(:avatar_image) unless permitted[:avatar_image].is_a?(uploaded_file)
      permitted
    end
end
