# frozen_string_literal: true

require_relative "lib/agilis_ads/version"

Gem::Specification.new do |spec|
  spec.name = "agilis-ads"
  spec.version = AgilisAds::VERSION
  spec.authors = ["Agilis Dating Ltd"]
  spec.email = ["help@agilis.dating"]

  spec.summary = "Ruby client for the Agilis Advertising REST API"
  spec.description = "Create and manage Agilis Offers, Events and webhook endpoints, and verify webhook signatures."
  spec.homepage = "https://github.com/agilisdating/agilis-ads-ruby"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["documentation_uri"] = "https://www.agilis.dating/api-doc"
  spec.metadata["bug_tracker_uri"] = "#{spec.homepage}/issues"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir["lib/**/*.rb", "sig/**/*.rbs", "README.md", "LICENSE", "CHANGELOG.md", "SECURITY.md"]
  spec.require_paths = ["lib"]
end
