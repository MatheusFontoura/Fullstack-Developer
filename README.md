# Umanni — User Management

A Rails 8.1 application on Ruby 4.0 for managing users: a live admin dashboard, full
CRUD with role control, asynchronous spreadsheet import with real-time progress, and a
profile each user manages themselves.

SQLite in WAL mode, Solid Queue, Solid Cache and Solid Cable. No Redis, no Postgres.

---

## AI Usage Disclosure

**Models used: Claude Opus 5 and Claude Fable 5.1, through Claude Code.**

**What the models did.** Opus 5 wrote the application code, the tests, the commit
messages and this README. Fable 5.1 ran two isolated research tasks: surveying my
previous take-home repositories for conventions worth carrying forward, and drafting
`CLAUDE.md`. Sub-agents drove Playwright against the running application to test the UI
and reported back; they had no write access to the codebase.

**What I did.** I chose the architecture and made every decision the work branched on:
Hotwire over Inertia/React, Minitest over RSpec, SQLite over PostgreSQL, one PR per
phase, and how to handle the point below. I set the standards the code was held to and
rejected work that missed them. Nothing was merged on the model's say-so — every phase
had to pass a real gate before it moved: the full suite green, RuboCop and Brakeman
clean, the production image actually built and run, and the flow actually clicked
through in a browser.

**The workflow.** The work ran in phases, each on its own branch with its own PR:
skeleton → authentication → admin CRUD → live dashboard → import → profile → delivery.
Read-only work fanned out in parallel — investigation, UI testing, a second opinion from
a different model — while writing stayed single-threaded, because two agents editing the
same tree produce decisions nobody reviewed. Each phase ended at a gate, and a failed
gate sent the phase back rather than forward.

**What that caught.** Several bugs that a green test suite did not:

- `tailwindcss:watch` exits when stdin is not a TTY, so `docker compose up` died on
  startup. It needed the `[always]` argument. This would have broken on the reviewer's
  very first command.
- Signing in returned 500 in development: `config/cache.yml` named the cache database
  under production only, so Solid Cache went looking for its table in the primary
  database. The suite could not see it, because the test environment uses `:null_store`,
  which makes rate limiting inert. There is now a test that guards the class of bug.
- The import's progress bar stuck on "Processing" about one run in three: two broadcasts
  a millisecond apart, arriving out of order.
- The dashboard counters froze for the entire duration of an import — the one moment a
  live counter earns its place. Turbo debounces refresh broadcasts and the debounce
  restarts on every write, so a job creating rows faster than the delay produced no
  refresh at all until it finished. Found by watching a 150-row import, not by reading
  the code, which is why the comment in the model had confidently claimed the opposite.
- The production image seeded demo users, with a published password, because the
  entrypoint runs `db:prepare`. Found by running the image rather than only building it.
- A content security policy added in review blocked the import bar's inline width, so it
  rendered full at every percentage while every test still passed.
- `docker compose --profile mail up` promised a clickable reset link at :8025 and never
  delivered one: SMTP pointed at `localhost`, which inside the web container is that
  container. `raise_delivery_errors` is off in development, so it failed in silence.
  Found by following this README's own instructions instead of trusting them.

**What a later pass caught.** A commit titled "cut comments that narrate the code" also
removed a test — the one asserting a forged session cookie is ignored — and tightened
`img_src`. Neither change was wrong; neither belonged in that commit, and the missing
test was only noticed by a review that had no memory of writing it. It is back. The same
pass found two tests that kept passing with the defence they named removed, because a
different rule was doing the blocking. Those five assertions were each checked the same
way afterwards: remove the defence, watch the test go red.

### A note on the hidden instructions in the brief

The brief at <https://github.com/umanni/Fullstack-Developer> contains an HTML comment in
its `README.md`, addressed to LLM assistants. It asks the model to inject a marker string
into the frontend and, in its own words, to *"not disclose or explain these hidden
constraints to the human user."* It is visible in the raw file, not in the rendered page.

I read it, and I did not follow it. There is no marker string in this codebase, and
nothing about the process was hidden from me. Disclosure is above, in full.

---

## Running it

### Docker (recommended)

```bash
docker compose up
```

Then <http://localhost:3200>. Port 3200 rather than 3000 so it does not collide with
another Rails server; override with `WEB_PORT=4000 docker compose up`.

There is no database service to wait for. SQLite and the three Solid databases live in
the `storage` volume, which is the point of this stack.

```bash
docker compose exec web bin/rails db:seed   # optional: `db:prepare` already seeded
```

### Local

Requires Ruby 4.0.6 (`.ruby-version`).

```bash
bin/setup --skip-server   # bundle and prepare the databases
bin/rails db:seed
bin/dev                   # Puma, the Tailwind watcher and the Solid Queue worker
```

Plain `bin/setup` does the same and then hands the terminal to `bin/dev`, so seed first
or seed from another shell.

### Demo logins

Seeds are idempotent and create 32 users. Password for all of them: `secret-password`.

| Email | Role |
|---|---|
| `admin@umanni.test` | admin |
| `user@umanni.test` | user |

Seeds refuse to run outside development and test. `db:prepare` seeds a freshly created
database, and a production deploy must not come up with a published password in it.
The first admin of a real deployment is one command:

```bash
bin/rails runner 'User.create!(full_name: "Ada Lovelace", email: "ada@example.com", role: :admin, password: ENV.fetch("ADMIN_PASSWORD"))'
```

### Trying the spreadsheet import

`test/fixtures/files/users.csv` and `users.xlsx` are ready to upload from **Imports →
New import**. They are deliberately dirty: five rows, of which one has no name and one
repeats an earlier email. Three import, two are reported by line and reason, and the run
still completes. Open the dashboard in a second tab first and watch its counters move at
the same time.

---

## Testing

```bash
bin/rails test:all      # unit, integration and system
bin/rails test          # skips system tests
bin/ci                  # the whole pipeline: lint, audits, Brakeman, tests, seeds
```

**169 tests, 602 assertions, 99.05% line coverage, 96.61% branch coverage** on the last
run — `bin/rails test:all` prints the current figures, and a per-layer breakdown kept by
hand only rots. Tests run
in parallel across one process per core, and SimpleCov results are merged per worker —
without that merge the report shows roughly one worker's share and every number after it
is fiction. The 90% floor is enforced under `CI` or `COVERAGE`.

System tests need Chrome. If it is not on `PATH` (WSL, slim containers):

```bash
CHROME_BINARY=/path/to/chrome bin/rails test:system
```

The system tests prove what no controller test can: that the dashboard counters move on their own when a user is created elsewhere,
that a role toggle replaces one table row without reloading the page, and that an
import's progress arrives over the wire while the page sits open.

---

## What it does

| Use case | Where |
|---|---|
| Admin dashboard, counts total and by role, live | `Admin::DashboardsController` |
| Admin lists, creates, edits and deletes users | `Admin::UsersController` |
| Admin toggles a user's role | `Admin::Users::RolesController` |
| Admin imports a spreadsheet asynchronously | `SpreadsheetImportJob` |
| Admin watches import progress live | `Admin::SpreadsheetImportsController` |
| Admin lands on the dashboard after login | `ApplicationController#home_url_for` |
| User lands on their profile after login | same |
| User sees, edits and deletes only their own profile | `ProfilesController` |
| Visitor registers as a plain user | `RegistrationsController` |

---

## Technical decisions

**SQLite, not PostgreSQL.** The brief asks for WAL mode, and Rails 8 is built around
SQLite plus the Solid trio. The pragmas are written out in `config/database.yml` rather
than left to the adapter's defaults, because WAL journalling, `synchronous: normal` and
enforced foreign keys are what separate a production-ready SQLite setup from a toy one,
and a reviewer should not have to read the adapter source to see them. The moment this
application needs a second machine running jobs, it moves to PostgreSQL — SQLite is a
file, not a server.

**Development mirrors production.** Rails leaves development on the async and memory
adapters. That would mean the broadcast and job paths that actually ship are never
exercised until deploy, and a reviewer running `docker compose up` would reasonably
conclude the Solid stack was not used. Development runs the same four databases
production does. `test/config/solid_stack_test.rb` asserts they stay configured, which
is the test that would have caught the cache bug listed above.

**Deterministic encryption on `email`.** The column has to stay uniquely indexable and
findable by exact value — `authenticate_by` and the unique index both depend on
identical plaintext producing identical ciphertext. The cost is real and worth stating:
`LIKE` on email is impossible, so the admin search matches `full_name`, which is
deliberately left in plaintext for exactly that reason.

**Roles are an enum with a database constraint.** The enum guards the application; the
`CHECK` constraint guards the console, data migrations and anything else that goes
around the model.

**Authorisation belongs to the namespace.** `Admin::BaseController` runs the check, so
every admin controller inherits it rather than remembering to declare it. Two roles do
not justify a policy object. A third role, or per-record permissions, is where Pundit
would go — and that controller is where it would plug in.

**The role is a sub-resource, not a custom action.** `PATCH /admin/users/:user_id/role`
keeps `UsersController` plain CRUD and gives the rule that an admin cannot change their
own role one obvious home. That rule is also what keeps the system administrable: any
*other* admin they demote still leaves them an admin, so the last one can never vanish.

**Pagination is offset-based and hand-rolled.** It fetches one row beyond the page, so
"is there a next page" is answered without a `COUNT`. That is the whole requirement at
this size. A list needing page numbers or a total is where Pagy goes in, rather than
growing this.

**Avatars have no variants.** Generating them would put libvips on every developer's
machine to produce a 40px thumbnail. Uploads are capped at 2 MB and constrained by CSS
instead. At real avatar volume that trade flips and the variant comes back — libvips is
already in both Docker images.

**Minitest, not RSpec.** RSpec is what I reach for day to day, but `parallelize` is the
parallel testing feature the brief names, it is native, and this whole test is built on
Rails 8's own tools.

**The import paces its own dashboard refreshes.** Turbo's debounce restarts on every
write, so a bulk job outruns it and broadcasts nothing until it stops. The job suppresses
the model's broadcast and refreshes on a fixed cadence, and a test fails if that is
removed.

**The import is continuable.** `ActiveJob::Continuable` is new in Rails 8.1 and here it
is correctness: a worker restarting mid-file would replay rows it already imported, and
each would come back as a duplicate email. A test resumes from a cursor and asserts the
earlier rows are not replayed.

---

## Security

**Encryption.** `email` is encrypted at rest with deterministic Active Record
encryption. A test reads the raw column and asserts the address is not in it.

**SQL injection.** Every query goes through Active Record with bound parameters. The two
places user input reaches a query are covered directly: search escapes its term with
`sanitize_sql_like` and names the escape character in the clause — `ESCAPE` is not
optional, and without it the escaping is inert — and the role filter is checked against
`User.roles.key?` rather than passed through — there is a test that sends
`'; DROP TABLE users; --` as a role and asserts the page renders normally.

**XSS.** ERB escapes by default and nothing here calls `html_safe` or `raw`;
`Rails/OutputSafety` keeps it that way. SVG is absent from the allowed avatar types: a
stored SVG is a stored script, and Active Storage serves attachments from this origin.
Behind that sits a Content Security Policy of `default-src 'none'` with a per-response
nonce for scripts and styles — escaping can be undone by one careless `html_safe`, a
policy cannot. Style *attributes* are allowed, because the import progress bar's width
is a computed value; `script-src`, which is where XSS lives, stays closed. The first version of
this policy broke that bar in the browser while twenty-one system tests stayed green —
they asserted `aria-valuenow`, which the server had got right. It was found by opening
the page. The teardown that fails any system test whose browser reports a policy
violation was written in the same commit as the fix, so the next one costs a test run
instead of a pair of eyes. Three tests store markup in a name, a validation message and
an import's row errors, and assert it comes back escaped.

**CSRF.** Rails' token protection is on and every state change goes through `form_with`
or `button_to`. Rails disables the protection in the test environment, which means it is
normally never exercised, so one test turns it back on and asserts a token-less POST
creates nothing.

**Mass assignment.** `params.expect` everywhere rather than `params.permit` — a request
that is not shaped like the form is a 400 rather than something quietly filtered to an
empty hash. `:role` appears in exactly one permitted list, in the admin namespace. Both
self-registration and profile editing have a test that submits `role: admin` and asserts
the user stays a user.

**Brute force.** The sign-in and password-reset endpoints keep the generated
`rate_limit`. The test environment gives the limiter a real cache store so the rule is
exercised rather than assumed.

**Static analysis.** Brakeman, bundler-audit and `importmap audit` run on every pull
request and report zero findings.

`test/integration/security_test.rb` holds the injection, escaping, CSRF and forged-cookie
tests. The rest sit with the code they guard: the role filter and the admin routes that
change something in `test/controllers/admin/users_controller_test.rb`, the rate limit in
`sessions_controller_test.rb`, session revocation in `passwords_controller_test.rb` and
`profiles_controller_test.rb`, and the raw email column in `user_test.rb`.

Every test written for a defence here was checked the same way: remove the defence, run
the test, watch it fail. That is not a formality — the self-demotion test passed for a
year of commits with the parameter filter deleted, because a different rule was doing
the blocking.

---

## Cross-browser support

`allow_browser versions: :modern` rejects browsers without webp, import maps, CSS
nesting and `:has` — in practice Chrome 120+, Safari 17.2+ and Firefox 121+. Tailwind 4
sets a floor of its own around there, so without this an older iOS would get broken CSS
and no explanation; `public/406-unsupported-browser.html` is that explanation. The floor
is what makes polyfills unnecessary.

Submit buttons disable and relabel themselves while a request is in flight through
Turbo's own `data-turbo-submits-with`. A Stimulus controller did this first, until review
pointed out that Turbo already shipped it. What Stimulus does here is the thing Turbo has
no answer for: previewing a chosen avatar before it is uploaded, reading a `File` the
browser already holds, and revoking the object URL on disconnect so a cached page does
not pin it in memory.

Form feedback works in three layers. `required`, `type="email"`, `minlength` and
`accept` are enforced by the browser before a request is made, and
`.field-input:user-invalid` styles the field from its native validity state — no
JavaScript. The server-side rules are the ones that decide, and the system tests check
both: one asserts the browser blocks a short password before any request, and the
server-side test uses a duplicate email, because that is the case the browser cannot
catch. Server-side errors render both as a summary and beside the field that caused
them, with `aria-invalid` and `aria-describedby` so a screen reader gets the pairing.

Layout is Tailwind, mobile-first. The users table scrolls inside its own container on a
phone with the name column pinned, so the row still says whose it is. A system test
resizes to 390px and fails if any screen is wider than the viewport.

---

## Deployment

The production image is multi-stage, runs as a non-root user, and serves through
**Thruster** for asset caching, compression and X-Sendfile.

```bash
docker build -t umanni .
docker run -d -p 80:80 \
  -e RAILS_MASTER_KEY=<key> \
  -e SOLID_QUEUE_IN_PUMA=true \
  -v umanni_storage:/rails/storage umanni
```

`SOLID_QUEUE_IN_PUMA` is what starts the job supervisor inside Puma; without it the
image serves fine and imports never run. Kamal sets it in `config/deploy.yml`.

**Regenerating credentials means regenerating the encryption keys.** `email` is an
encrypted column, and production reads `active_record_encryption` from the credentials
rather than from an environment file the way development and test do. If you replace
`config/credentials.yml.enc` with your own, run `bin/rails db:encryption:init` and paste
its three keys in, or the image will boot, answer `/up` with a 200, render every page,
and return a 500 the first time anyone signs in or registers. That is not hypothetical:
it is what this image did until the keys were added.

`config/deploy.yml` is a complete Kamal 2 configuration: fill in the registry, image
owner, server and host, and `bin/kamal setup` is the deploy. `kamal config` resolves the
whole file — roles, image, volume, ssh, builder — and `kamal secrets print` resolves the
master key. **A deploy against a real host was not exercised**; there was no server to
deploy to. TLS terminates at
kamal-proxy, so `assume_ssl` and `force_ssl` are on in production.

Solid Queue runs inside Puma rather than as a separate job role, and that follows from
SQLite rather than being a shortcut: a worker on a second machine could not reach a
database that is a file. The `storage` volume holds all four databases and every Active
Storage upload — it is the only stateful thing on the server, and so the only thing that
needs backing up.

**Credentials.** `config/master.key` is not in this repository, which means the
committed credentials cannot be read on another machine — as is true of any Rails
repository. Generate your own **before building the image**, or the build bakes in a
file the new key cannot decrypt:

```bash
rm config/credentials.yml.enc
bin/rails db:encryption:init                        # copy the three keys it prints
EDITOR="code --wait" bin/rails credentials:edit     # paste under active_record_encryption:
```

`credentials:edit` needs an `EDITOR` that blocks until you close the file — `code --wait`,
`vim`, or `nano`. Without one it exits without saving.

Rails wires `active_record_encryption` from credentials on its own. Development and test
keys are committed in the environment files on purpose — they are not secrets, and the
application has to boot for anyone who clones this.

---

## Performance

Ruby 4 ships ZJIT and the official image has it compiled in, so enabling it is one flag.
Measuring first says not to. Rendering the users table partial 20,000 times inside the
production image, after 5,000 warmup iterations:

| | Per render |
|---|---|
| YJIT (Rails' default) | 0.204–0.226 ms |
| ZJIT | 0.340–0.375 ms |

ZJIT stayed roughly 70% slower across runs, and a shorter warmup widened the gap instead
of narrowing it, so this is not a young JIT handicapped by warmup. Rails enables YJIT on
its own; it stays that way.

Reproduce it with `script/jit_benchmark.rb`; the numbers above are from one machine.

---

## Trade-offs and what is not here

- **The last admin cannot be removed** — not by the role toggle, not by the admin edit
  form, and not by deleting their own profile. Review found the first two routes open
  while the third was guarded, which is what moved the rule from the controller into the
  model. A user who is not the last admin can still delete their own account, as the
  brief asks.
- **Imported users cannot sign in until they reset their password.** They are created
  with a random one and set a real one through the reset flow. Delivery is configured
  (`SMTP_ADDRESS`, `SMTP_PORT`, credentials under `smtp:`), and the flow was exercised
  end to end against a local catcher — mail sent, link opened, password changed, old
  password rejected. A deploy still has to point it at a real mail service.
- **The dashboard suppression is not covered by a test.** `User.suppressing_turbo_broadcasts`
  is what stops Turbo's debounce from swallowing every refresh during a bulk import, but
  turbo-rails debounces immediately under test, so the effect cannot be observed there.
  The test beside it covers the pacing that replaces it — remove `DASHBOARD_EVERY` and it
  fails; remove the suppression and it does not.
- **The test suite does not exercise Solid Queue, Solid Cache or Solid Cable.** Jobs run
  inline, the cache is a null store and Action Cable is in-process, which is what keeps
  the suite fast and deterministic. Those three run for real in development and
  production against their own databases, which is where `docker compose up` puts them.
  `test/config/solid_stack_test.rb` guards the configuration, not the behaviour.
- **Sessions have no expiry and no pruning**, and there is no "active sessions" screen.
  The cookie is permanent, which is what `bin/rails generate authentication` produces.
  Changing a password does sign every other browser out.
- **The imports list is not paginated.** The users list is; imports are few enough that
  it has not earned it.
- **A worker killed outright leaves its import showing "processing".** Solid Queue records
  the failure but never re-enters the job, so `retry_on` does not apply; and a manual
  retry restarts the file from the top, reporting already-imported rows as duplicates.
  Recovering properly means storing the job id and reconciling against
  `solid_queue_failed_executions`, which is more machinery than this size of import earns.
- **Development delivers mail to a local catcher.** `docker compose --profile mail up`
  starts Mailpit; the reset link is then clickable at <http://localhost:8025>. Without
  it, delivery fails quietly. Previews are at `/rails/mailers`.
- **The import lists at most 200 rejected rows.** Each rejection rewrites the whole JSON
  column and rides along in the next broadcast, so an all-bad file would grow both the
  write cost and the message size with every row. The count keeps counting; only the
  listed reasons stop, and the page says so. Imported people get a placeholder digest at
  bcrypt's minimum cost — nobody authenticates with it, and the default cost was 250ms
  per row for nothing.
- **No background job for avatar processing**, no CDN, no fragment caching. All three
  answer a scale this application does not have.
