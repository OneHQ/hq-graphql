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

  s.files = Dir["{lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  s.test_files = Dir["spec/**/*"]

  s.add_dependency "rails",                     "~> 4.2"
  s.add_dependency "graphql",                   "~> 1.0", ">= 1.9.6"

  s.add_development_dependency "rspec_junit_formatter",   "~> 0.3", ">= 0.3.0"
  s.add_development_dependency "testhq",                  "~> 1.0", ">= 1.0.0"
end
