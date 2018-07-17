require "testhq/coverage"  # Needs to be require at the top of this file!
                           # Coverage must also be enabled in the environment by setting
                           # environment variables, e.g. `COVERAGE=true` or `CODECLIMATE_REPO_TOKEN=...`.
                           # See https://github.com/OneHQ/testhq#code-coverage.

require "bundler/setup"
require "combustion"

silence_stream(STDOUT) do  # Hides a lot of output from Combustion init such as schema loading.
  Combustion.initialize! :all do
    # Disable strong parameters
    config.action_controller.permit_all_parameters = true
  end
end

require "byebug"
require "rspec/rails"
require "testhq"

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = [:expect]
  end

  config.use_transactional_fixtures = false

  config.include FactoryBot::Syntax::Methods

  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with :truncation # Clear everything
  end

  config.before(:each) do
    DatabaseCleaner.start
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end
end
