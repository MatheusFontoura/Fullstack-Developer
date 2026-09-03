# Measures a representative render-heavy request path under the interpreter, YJIT and
# ZJIT, so the choice in the Dockerfile rests on numbers from this machine rather than
# on a blog post.
#
#   docker run --rm umanni:prod bin/rails runner script/jit_benchmark.rb
#   docker run --rm -e RUBYOPT=--yjit umanni:prod bin/rails runner script/jit_benchmark.rb
#   docker run --rm -e RUBYOPT=--zjit umanni:prod bin/rails runner script/jit_benchmark.rb
#
# No benchmark gem: it stopped being a default gem in Ruby 4, and a monotonic clock
# is all this needs.

ITERATIONS = Integer(ENV.fetch("ITERATIONS", 5_000))
WARMUP = Integer(ENV.fetch("WARMUP", 500))

users = Array.new(50) do |index|
  User.new(id: index + 1, full_name: "Benchmark Person #{index}", email: "bench#{index}@umanni.test",
           role: index.even? ? "admin" : "user", created_at: Time.current)
end

def jit_name
  return "ZJIT" if defined?(RubyVM::ZJIT) && RubyVM::ZJIT.enabled?
  return "YJIT" if defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled?

  "interpreter"
end

# Warm the compiler and the template cache before the measured run.
WARMUP.times { |i| ApplicationController.render(partial: "admin/users/user", locals: { user: users[i % 50] }) }

started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
ITERATIONS.times { |i| ApplicationController.render(partial: "admin/users/user", locals: { user: users[i % 50] }) }
elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at

puts format("%-12s %6.2f s for %d renders (%.3f ms each, %d warmup)",
            jit_name, elapsed, ITERATIONS, elapsed * 1000 / ITERATIONS, WARMUP)
