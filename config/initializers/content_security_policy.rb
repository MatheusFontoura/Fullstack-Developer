# The second line of defence against XSS, after ERB's escaping. Escaping can be
# defeated by one careless `html_safe`; this cannot, because the browser refuses to run
# a script the policy did not allow.
#
# Everything is served from this origin: Propshaft ships the CSS and the import map
# ships the JavaScript, so there is no CDN to allow. Avatars are Active Storage blobs
# from :self, and `data:` covers the object URLs the avatar preview creates.
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :none
    policy.base_uri    :self
    policy.form_action :self
    policy.frame_ancestors :none
    policy.connect_src  :self
    policy.font_src     :self
    policy.img_src      :self, :data, :blob
    policy.object_src   :none
    policy.script_src   :self
    policy.style_src    :self
    # Style *attributes* only, which is what a computed width like the import progress
    # bar is. Nonces and hashes do not apply to attributes, and script-src — where XSS
    # actually lives — stays closed.
    policy.style_src_attr :unsafe_inline
  end

  # The import map is an inline <script>, so it needs a nonce to be allowed at all.
  # Random per response rather than derived from the session id: a visitor who has no
  # session yet would otherwise get an empty nonce, which matches nothing and blocks
  # the very script tag this exists to permit.
  config.content_security_policy_nonce_generator = ->(_request) { SecureRandom.base64(16) }
  # style-src as well as script-src: Turbo injects a <style> element for its navigation
  # progress bar and stamps it with the page nonce.
  config.content_security_policy_nonce_directives = %w[ script-src style-src ]
end
