# frozen_string_literal: true

lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require 'rack/attack/version'

Gem::Specification.new do |s|
  s.name = 'rack-attack'
  s.version = Rack::Attack::VERSION
  s.license = 'MIT'

  s.authors = ["Aaron Suggs"]
  s.description = "A rack middleware for throttling and blocking abusive requests"
  s.email = "aaron@ktheory.com"

  s.files = Dir.glob("{bin,lib}/**/*") + %w(Rakefile README.md)
  s.homepage = 'https://github.com/kickstarter/rack-attack'
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.summary = %q{Block & throttle abusive requests}
  s.test_files = Dir.glob("spec/**/*")

  s.metadata = {
    "bug_tracker_uri" => "https://github.com/kickstarter/rack-attack/issues",
    "changelog_uri" => "https://github.com/kickstarter/rack-attack/blob/master/CHANGELOG.md",
    "source_code_uri" => "https://github.com/kickstarter/rack-attack"
  }

  s.required_ruby_version = '>= 2.3'

  s.add_runtime_dependency 'rack', ">= 1.0", "< 3"

  s.add_development_dependency 'appraisal', '~> 2.2'
  s.add_development_dependency "bundler", ">= 1.17", "< 3.0"
  s.add_development_dependency 'minitest', "~> 5.11"
  s.add_development_dependency "minitest-stub-const", "~> 0.6"
  s.add_development_dependency 'rack-test', "~> 1.0"
  s.add_development_dependency 'rake', "~> 12.3"
  s.add_development_dependency "rubocop", "0.67.2"
  s.add_development_dependency "timecop", "~> 0.9.1"

  # byebug only works with MRI
  if RUBY_ENGINE == "ruby"
    s.add_development_dependency 'byebug', '~> 11.0'
  end

  # The following are potential runtime dependencies users may have,
  # which rack-attack uses only for testing compatibility in test suite.
  s.add_development_dependency 'actionpack', '~> 5.2'
  s.add_development_dependency 'activesupport', '~> 5.2'
end
