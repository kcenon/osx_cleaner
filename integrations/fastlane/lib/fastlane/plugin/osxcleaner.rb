# SPDX-License-Identifier: BSD-3-Clause
# Copyright (c) 2021-2025

require 'fastlane/plugin/osxcleaner/version'

module Fastlane
  module Osxcleaner
    def self.all_classes
      Dir[File.expand_path('**/{actions,helper}/*.rb', File.dirname(__FILE__))]
    end
  end
end

Fastlane::Osxcleaner.all_classes.each do |current|
  require current
end
