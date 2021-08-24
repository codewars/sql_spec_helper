# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name          = "sql_spec_helper"
  spec.version       = "0.1.2"
  spec.authors       = ["kazk"]
  spec.email         = []

  spec.summary       = "Spec helper for SQL challenges"
  spec.description   = "Spec helper for SQL challenges"
  spec.homepage      = "https://github.com/codewars/sql_spec_helper"
  spec.license       = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.3.0")

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/codewars/sql_spec_helper"

  spec.files = Dir["lib/**/*", "README.md", "LICENSE"]
  spec.require_paths = ["lib"]

  spec.add_dependency "sequel", ">= 5", "< 6"
  spec.add_dependency "daff", ">= 1", "< 2"
  spec.add_dependency "rspec-expectations", ">= 3", "< 4"

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
end
