class User < ApplicationRecord
  # SVG is absent on purpose. A stored SVG is a stored script, and Active Storage
  # serves attachments from the application's own origin.
  AVATAR_CONTENT_TYPES = %w[ image/png image/jpeg image/webp ].freeze
  AVATAR_MAX_SIZE = 2.megabytes

  # Anyone watching the admin dashboard is subscribed to this stream.
  DASHBOARD_STREAM = "dashboard".freeze

  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :spreadsheet_imports, dependent: :destroy
  has_one_attached :avatar_image

  # Deterministic so the column stays queryable and uniquely indexable. The cost is
  # that partial matching is gone: no LIKE on email, ever. The admin list searches
  # full_name, which is deliberately left in plaintext for that reason.
  encrypts :email, deterministic: true

  enum :role, { user: "user", admin: "admin" }, default: :user, validate: true

  # A lambda, not the bare symbol: the macro calls `send` on the record for anything
  # that does not respond to `call`, so `:dashboard` would look for User#dashboard.
  #
  # Turbo debounces these, and the debounce restarts on every write. A bulk import
  # writing faster than the delay therefore produces no broadcast at all until it
  # stops — which is why SpreadsheetImportJob suppresses this and paces the dashboard
  # itself rather than relying on the callback.
  broadcasts_refreshes_to ->(_user) { DASHBOARD_STREAM }

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :full_name, presence: true, length: { maximum: 120 }
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 8 }, allow_nil: true
  validate :avatar_image_must_be_a_supported_image

  scope :ordered, -> { order(:full_name, :id) }
  # Deterministic encryption rules out a partial match on email but not an exact one,
  # so an address is looked up whole and anything else searches the name.
  scope :matching, ->(term) {
    term = term.to_s.strip
    if term.include?("@")
      where(email: term.downcase)
    else
      where("full_name LIKE ?", "%#{sanitize_sql_like(term)}%")
    end
  }
  scope :with_role, ->(role) { where(role: role) }

  # Blank for an unsaved user, which is exactly the case on the "new user" form.
  def initials
    full_name.to_s.split.first(2).filter_map { |part| part[0] }.join.upcase
  end

  private
    def avatar_image_must_be_a_supported_image
      return unless avatar_image.attached?

      supported = avatar_image.content_type.in?(AVATAR_CONTENT_TYPES)
      oversized = avatar_image.byte_size > AVATAR_MAX_SIZE

      errors.add(:avatar_image, "must be a PNG, JPEG or WebP image") unless supported
      errors.add(:avatar_image, "must be under #{AVATAR_MAX_SIZE / 1.megabyte} MB") if oversized
    end
end
