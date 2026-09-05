class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

  # Deterministic so the column stays queryable and uniquely indexable. The cost is
  # that partial matching is gone: no LIKE on email, ever. The admin list searches
  # full_name, which is deliberately left in plaintext for that reason.
  encrypts :email, deterministic: true

  enum :role, { user: "user", admin: "admin" }, default: :user, validate: true

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :full_name, presence: true, length: { maximum: 120 }
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 8 }, allow_nil: true
end
