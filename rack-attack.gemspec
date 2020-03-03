# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

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
  s.summary = 'Block & throttle abusive requests'
  s.test_files = Dir.glob("spec/**/*")

  s.metadata = {
    "bug_tracker_uri" => "https://github.com/kickstarter/rack-attack/issues",
    "changelog_uri" => "https://github.com/kickstarter/rack-attack/blob/master/CHANGELOG.md",
    "source_code_uri" => "https://github.com/kickstarter/rack-attack"
  }

  s.required_ruby_version = '>= 2.4'

  s.add_runtime_dependency 'rack', ">= 1.0", "< 3"

  s.add_development_dependency 'appraisal', '~> 2.2'
  s.add_development_dependency "bundler", ">= 1.17", "< 3.0"
  s.add_development_dependency 'minitest', "~> 5.11"
  s.add_development_dependency 'rack-test', "~> 1.0"
  s.add_development_dependency 'rake', "~> 13.0"
  s.add_development_dependency "rubocop", "0.75.0"
  s.add_development_dependency "rubocop-performance", "~> 1.5.0"
  s.add_development_dependency "timecop", "~> 0.9.1"

  # byebug only works with MRI
  if RUBY_ENGINE == "ruby"
    s.add_development_dependency 'byebug', '~> 11.0'
  end

  s.add_development_dependency 'railties', '>= 4.2', '< 6.1'
end
