# Umanni user management

## Stack

- Ruby 4.0.6 (`.ruby-version`), Rails 8.1.3.1, Bundler 4.0.16.
- SQLite 3 via `sqlite3` 2.9.6. Solid Cache 1.0.10, Solid Queue 1.7.0, Solid Cable 4.0.2. No Redis anywhere.
- Propshaft, importmap-rails, Turbo, Stimulus, tailwindcss-rails 4.6.0 (Tailwind v4). Puma 8, Thruster in production.
- Minitest 6, Capybara + selenium-webdriver (headless Chrome), SimpleCov 1.1.1.
- RuboCop 1.90 with rubocop-rails-omakase, rubocop-minitest, rubocop-performance. Brakeman and bundler-audit in CI.

## Architecture

- Authentication is the Rails 8 generator output (`bin/rails generate authentication`), committed unmodified on its
  own and customised afterwards: signed `session_id` cookie, one `Session` row per browser, bcrypt digest,
  token-based password reset. `app/controllers/concerns/authentication.rb`, `Current.session`/`Current.user`.
- `User` has `full_name`, `email`, `password_digest`, `role`. `role` is a string-backed enum (`user`, `admin`) with
  `validate: true` and a database check constraint `users_role_check`.
- `email` uses `encrypts :email, deterministic: true`, so the unique index compares ciphertext and `authenticate_by`
  works, but `LIKE` on email is impossible. Dev/test keys live in `config/environments/{development,test}.rb` on
  purpose; production takes them from credentials (Rails default, nothing set in `production.rb`).
- `Admin::BaseController` runs `require_admin`; every admin controller inherits from it. Admin routes:
  `admin/dashboard` (show, placeholder page), `admin/users` (all but show), `admin/users/:user_id/role` (update).
- `Admin::Users::RolesController#update` toggles the role and answers with a Turbo Stream that replaces the row
  (`dom_id(user)`) and `#flash`. An admin cannot change their own role or delete themselves.
- Landing page after sign-in and at `/`: admins go to `admin_dashboard_url`, everyone else to `profile_url`
  (`ApplicationController#home_url_for`, reused by `HomeController`).
- Avatar is `has_one_attached :avatar_image` (Active Storage, Disk service). PNG/JPEG/WebP only, 2 MB cap, validated
  in the model. No variants; images are served at upload size and constrained by CSS.
- `Pagination` (`app/models/pagination.rb`) is a PORO: offset-based, fetches `per_page + 1` rows, no COUNT.
- `resource :profile` routes `show edit update destroy`; `ProfilesController` implements only `show`.
- Tailwind component layer in `app/assets/tailwind/application.css`: `card`, `field-*`, `btn-*`, `badge-*`. Tailwind v4
  will not `@apply` one component class inside another, hence the selector lists.

## Database topology

- `config/database.yml`: development and production each have four SQLite databases, `primary`, `cache`, `queue`,
  `cable`, under `storage/`. Test is a single database (`storage/test.sqlite3`).
- Pragmas are explicit: `journal_mode: wal`, `synchronous: normal`, `foreign_keys: true`, `mmap_size`,
  `journal_size_limit`, `cache_size`.
- `config/cache.yml` and `config/cable.yml` name their database in development and production; `cable.yml` uses
  `async` in test. `test/config/solid_stack_test.rb` asserts this stays true.
- Schema files: `db/schema.rb`, `db/cache_schema.rb`, `db/queue_schema.rb`, `db/cable_schema.rb`.

## Running it

- Docker: `docker compose up` builds `Dockerfile.dev`, runs `bin/rails db:prepare && bin/dev`, serves on host port
  3200 (`WEB_PORT=xxxx docker compose up` to change). Health check hits `/up`.
- Local: `bin/setup` (bundle, `db:prepare`, then `bin/dev`), or `bin/dev` alone. `bin/dev` runs foreman over
  `Procfile.dev`: `web`, `css` (Tailwind watcher), `jobs` (`bin/jobs`, Solid Queue). Default port 3000.
- Seeds (`bin/rails db:seed`) are idempotent, create 32 users, and refuse to run outside development and test —
  `db:prepare` seeds a freshly created database, and a production deploy must not come up with demo logins in it.
  Demo logins, password `secret-password`: `admin@umanni.test` (admin), `user@umanni.test` (user).
- Fixtures use `grace@umanni.test` (admin) and `ada@umanni.test` (user), same password.
- No SMTP is configured for development, so password-reset mail fails silently (`raise_delivery_errors = false`).
  Preview at `/rails/mailers`.
- `Dockerfile` is the production image: multi-stage, non-root, Thruster. `config/deploy.yml` is a Kamal stub with
  placeholder hosts.

## Testing

- `bin/rails test:all` runs unit, integration and system tests. `bin/rails test` skips system tests.
- Tests run in parallel (`workers: :number_of_processors`). SimpleCov results are merged per worker in
  `test_helper.rb`.
- Line coverage floor is 90%, enforced only when `CI` or `COVERAGE` is set. Branch coverage is reported, not enforced.
- System tests use headless Chrome. Set `CHROME_BINARY=/path/to/chrome` when Chrome is not on `PATH` (WSL, slim
  containers).
- Rate limiting is testable: `config.action_controller.cache_store = :memory_store` in test while the general store is
  `:null_store`; `test_helper.rb` clears it before each test.
- `bin/ci` (`config/ci.rb`) mirrors the remote pipeline locally: setup, RuboCop, bundler-audit, importmap audit,
  Brakeman, `bin/rails test`, `bin/rails test:system` and `db:seed:replant` in the test env. GitHub Actions (`.github/workflows/ci.yml`) runs the scans, lint and
  `bin/rails db:test:prepare test:all` on pull requests and pushes to `master`.

## Conventions

- Conventional Commits in English (`feat:`, `fix:`, `test:`, `chore:`, `ci:`, `refactor:`), with a body that explains
  the decision. Default branch is `master`.
- `params.expect`, not `permit`, in every controller that takes a form.
- `:role` is permitted only in `Admin::UsersController#user_params`. Self-registration never accepts it.
- Admin search matches `full_name` only (`User.search`, escaped with `sanitize_sql_like`). Role filter is checked
  against `User.roles` before it reaches the query.
- RuboCop: omakase plus a stricter layer (`.rubocop.yml`: metrics ceilings, Rails cops, Minitest and Performance
  plugins, line length 120). Run `bin/rubocop -A` after editing Ruby.
- Error responses render with `status: :unprocessable_content`; destroy redirects use `status: :see_other`.

## Gotchas

- `Procfile.dev` must keep `tailwindcss:watch[always]`. Without `always` the watcher exits when stdin is not a TTY
  (Docker Compose), and foreman takes the whole application down with it.
- `config/cache.yml` needs `database: cache` under development as well as production. Missing it, Solid Cache looks for
  `solid_cache_entries` in the primary database and every `rate_limit` action returns 500 on its first write. The test
  suite never sees this because test uses `:null_store`; `test/config/solid_stack_test.rb` guards it instead.
- `config.active_record.encryption.encrypt_fixtures = true` in `test.rb` is required for fixture emails to match the
  encrypted column.
- `shared/_avatar.html.erb` checks `avatar_image.attachment&.persisted?`, not `attached?`. Re-rendering a form after a
  failed create otherwise asks for a URL to a blob with no id and raises.
- In system tests `click_on` returns before the request completes. `ApplicationSystemTestCase#sign_in_as` ends with
  `assert_no_current_path new_session_path` so the next `visit` is not made as an anonymous visitor.
- `Dockerfile.dev` has no `USER`, so the container runs as root. `tmp` and `log` are named volumes in `compose.yaml`;
  bind-mounting them leaves root-owned files on the host that block a local `bin/dev` from writing its bootsnap cache.
  Read container logs with `docker compose logs`.
- libvips is only needed for Active Storage variants. Both Docker images and the CI test job install it; a host
  without it runs everything, because avatars do not use variants.
- `sign_in_as` in `test/test_helpers/session_test_helper.rb` writes a cookie into a test request and is for
  integration tests only; system tests use the browser-driven override in `ApplicationSystemTestCase`.
