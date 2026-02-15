# frozen_string_literal: true

$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "hq/graphql/version"
# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "hq-graphql"
  s.version     = HQ::GraphQL::VERSION
  s.authors     = ["Danny Jones"]
  s.email       = ["dpjones09@gmail.com"]
  s.homepage    = "https://github.com/OneHQ/hq-graphql"
  s.summary     = "OneHQ GraphQL Library"
  s.description = "OneHQ GraphQL Library"
  s.license     = "MIT"
  s.required_ruby_version = ">= 3.4"

  s.files = Dir["{lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]

  s.add_dependency "rails",                                      ">= 6.0", "<= 7.2.3"

  s.add_dependency "graphql",                                    "~> 1.13"
  s.add_dependency "graphql-batch",                              "~> 0.4"
  s.add_dependency "graphql-schema_comparator",                  "~> 1.0"
  s.add_dependency "pg",                                         "~> 1.1"

  s.add_development_dependency "byebug",                         "~> 12.0"
  s.add_development_dependency "combustion",                     "~> 1.5"
  s.add_development_dependency "concurrent-ruby",                "1.3.5"
  s.add_development_dependency "database_cleaner",               "~> 2.1"
  s.add_development_dependency "factory_bot_rails",              "~> 6.5"
  s.add_development_dependency "faker",                          "~> 3.5"
  s.add_development_dependency "rspec",                          "~> 3.8"
  s.add_development_dependency "rspec_junit_formatter",          "~> 0.6"
  s.add_development_dependency "rspec-rails",                    "~> 7.0"
  s.add_development_dependency "rubocop",                        "~> 1.81"
  s.add_development_dependency "rubocop-performance",            "~> 1.26"
  s.add_development_dependency "rubocop-rails",                  "~> 2.34"
end
