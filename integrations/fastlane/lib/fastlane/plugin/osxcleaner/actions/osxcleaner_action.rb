# SPDX-License-Identifier: BSD-3-Clause
# Copyright (c) 2021-2025

require 'fastlane/action'
require_relative '../helper/osxcleaner_helper'

module Fastlane
  module Actions
    class OsxcleanerAction < Action
      def self.run(params)
        helper = Helper::OsxcleanerHelper

        # Ensure OSX Cleaner is installed
        unless helper.osxcleaner_path
          helper.install_osxcleaner(version: params[:version])
        end

        osxcleaner = helper.osxcleaner_path
        UI.user_error!("OSX Cleaner not found") unless osxcleaner

        # Build command
        cmd = [
          osxcleaner,
          'clean',
          '--non-interactive',
          '--format', 'json',
          '--level', params[:level],
          '--target', params[:target]
        ]

        if params[:min_space]
          cmd += ['--min-space', params[:min_space].to_s]
          cmd += ['--min-space-unit', params[:min_space_unit]]
        end

        cmd << '--dry-run' if params[:dry_run]

        UI.message("Running: #{cmd.join(' ')}")

        # Execute cleanup
        output = Actions.sh(cmd.join(' '), log: false, error_callback: ->(_) {})

        # Parse results
        result = helper.parse_json_output(output)

        if result.empty?
          UI.error("Failed to parse cleanup results")
          UI.message(output)
          return nil
        end

        # Display results
        display_results(result, helper)

        # Return structured result
        {
          status: result['status'],
          freed_bytes: result['freed_bytes'] || 0,
          freed_formatted: result['freed_formatted'] || helper.format_bytes(result['freed_bytes']),
          files_removed: result['files_removed'] || 0,
          duration_ms: result['duration_ms'] || 0,
          available_before: result.dig('before', 'available'),
          available_after: result.dig('after', 'available')
        }
      end

      def self.display_results(result, helper)
        status = result['status'] || 'unknown'
        freed = result['freed_formatted'] || helper.format_bytes(result['freed_bytes'])
        files = result['files_removed'] || 0
        duration = result['duration_ms'] || 0

        UI.success("╔════════════════════════════════════════════╗")
        UI.success("║          OSX Cleaner Results               ║")
        UI.success("╠════════════════════════════════════════════╣")
        UI.success("║ Status:        #{status.ljust(26)}║")
        UI.success("║ Space Freed:   #{freed.ljust(26)}║")
        UI.success("║ Files Removed: #{files.to_s.ljust(26)}║")
        UI.success("║ Duration:      #{duration.to_s.ljust(22)} ms ║")
        UI.success("╚════════════════════════════════════════════╝")
      end

      def self.description
        "Automated disk cleanup for macOS using OSX Cleaner"
      end

      def self.authors
        ["kcenon"]
      end

      def self.return_value
        "Returns a hash with cleanup results: status, freed_bytes, freed_formatted, files_removed, duration_ms"
      end

      def self.details
        [
          "OSX Cleaner helps prevent 'No space left on device' errors during iOS/macOS builds",
          "by cleaning up caches, derived data, and temporary files.",
          "",
          "It automatically installs OSX Cleaner if not present and runs cleanup",
          "with the specified configuration."
        ].join("\n")
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(
            key: :level,
            env_name: "OSXCLEANER_LEVEL",
            description: "Cleanup level: light, normal, deep",
            optional: true,
            default_value: "normal",
            verify_block: proc do |value|
              unless %w[light normal deep].include?(value)
                UI.user_error!("Invalid level '#{value}'. Use: light, normal, deep")
              end
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :target,
            env_name: "OSXCLEANER_TARGET",
            description: "Cleanup target: browser, developer, logs, all",
            optional: true,
            default_value: "all",
            verify_block: proc do |value|
              unless %w[browser developer logs all].include?(value)
                UI.user_error!("Invalid target '#{value}'. Use: browser, developer, logs, all")
              end
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :min_space,
            env_name: "OSXCLEANER_MIN_SPACE",
            description: "Minimum available space threshold (cleanup triggers if below this)",
            optional: true,
            type: Integer
          ),
          FastlaneCore::ConfigItem.new(
            key: :min_space_unit,
            env_name: "OSXCLEANER_MIN_SPACE_UNIT",
            description: "Unit for min_space: mb, gb, tb",
            optional: true,
            default_value: "gb",
            verify_block: proc do |value|
              unless %w[mb gb tb].include?(value)
                UI.user_error!("Invalid unit '#{value}'. Use: mb, gb, tb")
              end
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :dry_run,
            env_name: "OSXCLEANER_DRY_RUN",
            description: "Preview mode without actual deletion",
            optional: true,
            is_string: false,
            default_value: false
          ),
          FastlaneCore::ConfigItem.new(
            key: :version,
            env_name: "OSXCLEANER_VERSION",
            description: "OSX Cleaner version to install (default: latest)",
            optional: true,
            default_value: "latest"
          )
        ]
      end

      def self.is_supported?(platform)
        [:mac].include?(platform)
      end

      def self.example_code
        [
          '# Basic cleanup',
          'osxcleaner',
          '',
          '# Pre-build cleanup with space check',
          'osxcleaner(',
          '  level: "normal",',
          '  target: "developer",',
          '  min_space: 20,',
          '  min_space_unit: "gb"',
          ')',
          '',
          '# Post-build deep cleanup',
          'osxcleaner(',
          '  level: "deep",',
          '  target: "all"',
          ')',
          '',
          '# Dry run preview',
          'result = osxcleaner(dry_run: true)',
          'UI.message("Would free: #{result[:freed_formatted]}")'
        ]
      end

      def self.category
        :building
      end
    end
  end
end
