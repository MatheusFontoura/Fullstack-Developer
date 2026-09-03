class User < ApplicationRecord
  # SVG is absent on purpose. A stored SVG is a stored script, and Active Storage
  # serves attachments from the application's own origin.
  AVATAR_CONTENT_TYPES = %w[ image/png image/jpeg image/webp ].freeze
  AVATAR_MAX_SIZE = 2.megabytes

  has_secure_password
  has_many :sessions, dependent: :destroy
  has_one_attached :avatar_image

  # Deterministic so the column stays queryable and uniquely indexable. The cost is
  # that partial matching is gone: no LIKE on email, ever. The admin list searches
  # full_name, which is deliberately left in plaintext for that reason.
  encrypts :email, deterministic: true

  enum :role, { user: "user", admin: "admin" }, default: :user, validate: true

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :full_name, presence: true, length: { maximum: 120 }
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 8 }, allow_nil: true
  validate :avatar_image_must_be_a_supported_image

  scope :ordered, -> { order(:full_name, :id) }
  scope :search, ->(term) { where("full_name LIKE ?", "%#{sanitize_sql_like(term.to_s.strip)}%") }
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
