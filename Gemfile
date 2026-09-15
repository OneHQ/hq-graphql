# frozen_string_literal: true

source "https://rubygems.org"
gem "bundler-audit",                          "~> 0.9.3"
gem "ostruct",                                "~> 0.6"

# fix rspec conflict caused by rails 6
gem "net-imap", require: false
gem "net-pop",  require: false
gem "net-smtp", require: false

source "https://vLEyAxzPMpJK8itRTFw6@gem.fury.io/onehq/" do
  gem "testhq", "= 6.1.0"
end

gemspec

# Verify both supported Rails series during the upgrade.
def next?
  File.basename(__FILE__) == "Gemfile.next"
end

gem "next_rails"
gem "rails", next? ? "= 8.1.3.1" : "= 8.0.5.1"
