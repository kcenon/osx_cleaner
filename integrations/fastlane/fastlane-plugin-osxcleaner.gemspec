# SPDX-License-Identifier: BSD-3-Clause
# Copyright (c) 2021-2025

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'fastlane/plugin/osxcleaner/version'

Gem::Specification.new do |spec|
  spec.name          = 'fastlane-plugin-osxcleaner'
  spec.version       = Fastlane::Osxcleaner::VERSION
  spec.author        = 'kcenon'
  spec.email         = 'kcenon@gmail.com'

  spec.summary       = 'Automated disk cleanup for macOS builds'
  spec.description   = 'Fastlane plugin for OSX Cleaner - helps prevent "No space left on device" errors during iOS/macOS builds by cleaning up caches and temporary files.'
  spec.homepage      = 'https://github.com/kcenon/osx_cleaner'
  spec.license       = 'BSD-3-Clause'

  spec.files         = Dir["lib/**/*"] + %w[README.md LICENSE]
  spec.require_paths = ['lib']

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/kcenon/osx_cleaner'
  spec.metadata['changelog_uri'] = 'https://github.com/kcenon/osx_cleaner/blob/main/CHANGELOG.md'

  spec.required_ruby_version = '>= 2.6.0'

  spec.add_development_dependency('bundler', '>= 2.0')
  spec.add_development_dependency('fastlane', '>= 2.0')
  spec.add_development_dependency('pry')
  spec.add_development_dependency('rake')
  spec.add_development_dependency('rspec', '~> 3.0')
  spec.add_development_dependency('rspec_junit_formatter')
  spec.add_development_dependency('rubocop', '~> 1.0')
  spec.add_development_dependency('simplecov')
end
