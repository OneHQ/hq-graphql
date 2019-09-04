require "byebug"
require "combustion"

Combustion.initialize! :all do
  config.load_defaults 6.0
end

require "database_cleaner"
require "factory_bot_rails"
require "faker"
require "rspec/rails"

RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods

  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with :truncation # Clear everything
  end

  config.before(:each) do
    ::HQ::GraphQL.reset!
    DatabaseCleaner.start
  end

  config.after(:each) do
    DatabaseCleaner.clean
    ::HQ::GraphQL.reset!
  end
end
