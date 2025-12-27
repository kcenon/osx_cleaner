# SPDX-License-Identifier: BSD-3-Clause
# Copyright (c) 2021-2025

require 'fastlane_core/ui/ui'
require 'json'

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?(:UI)

  module Helper
    class OsxcleanerHelper
      class << self
        def install_osxcleaner(version: 'latest')
          UI.message("Installing OSX Cleaner...")

          if version == 'latest' || version == 'source'
            install_from_source
          else
            install_from_release(version) || install_from_source
          end

          verify_installation
        end

        def osxcleaner_path
          @osxcleaner_path ||= find_osxcleaner
        end

        def find_osxcleaner
          paths = [
            '/usr/local/bin/osxcleaner',
            "#{ENV['HOME']}/bin/osxcleaner",
            "#{ENV['HOME']}/.local/bin/osxcleaner",
            '.build/release/osxcleaner'
          ]

          paths.find { |path| File.executable?(path) }
        end

        def parse_json_output(output)
          lines = output.split("\n")
          json_line = lines.find { |line| line.strip.start_with?('{') }

          return {} unless json_line

          JSON.parse(json_line)
        rescue JSON::ParserError => e
          UI.error("Failed to parse JSON output: #{e.message}")
          {}
        end

        def format_bytes(bytes)
          units = ['B', 'KB', 'MB', 'GB', 'TB']
          return '0 B' if bytes.nil? || bytes == 0

          exp = (Math.log(bytes) / Math.log(1024)).to_i
          exp = [exp, units.length - 1].min

          format('%.2f %s', bytes.to_f / (1024**exp), units[exp])
        end

        private

        def install_from_source
          UI.message("Building OSX Cleaner from source...")

          temp_dir = '/tmp/osx_cleaner_build'

          Actions.sh("rm -rf #{temp_dir}")
          Actions.sh("git clone --depth 1 https://github.com/kcenon/osx_cleaner.git #{temp_dir}")
          Actions.sh("cd #{temp_dir} && swift build -c release")

          install_path = "#{ENV['HOME']}/bin"
          FileUtils.mkdir_p(install_path)
          FileUtils.cp("#{temp_dir}/.build/release/osxcleaner", "#{install_path}/osxcleaner")
          FileUtils.chmod(0o755, "#{install_path}/osxcleaner")

          @osxcleaner_path = "#{install_path}/osxcleaner"

          Actions.sh("rm -rf #{temp_dir}")
        end

        def install_from_release(version)
          UI.message("Downloading OSX Cleaner #{version}...")

          url = "https://github.com/kcenon/osx_cleaner/releases/download/#{version}/osxcleaner-macos.tar.gz"
          temp_file = '/tmp/osxcleaner.tar.gz'

          begin
            Actions.sh("curl -sL --fail '#{url}' -o #{temp_file}")

            install_path = "#{ENV['HOME']}/bin"
            FileUtils.mkdir_p(install_path)

            Actions.sh("tar -xzf #{temp_file} -C /tmp")
            FileUtils.cp('/tmp/osxcleaner', "#{install_path}/osxcleaner")
            FileUtils.chmod(0o755, "#{install_path}/osxcleaner")

            @osxcleaner_path = "#{install_path}/osxcleaner"

            FileUtils.rm_f(temp_file)
            true
          rescue StandardError => e
            UI.important("Failed to download release: #{e.message}")
            false
          end
        end

        def verify_installation
          path = osxcleaner_path
          UI.user_error!("OSX Cleaner installation failed") unless path

          version = Actions.sh("#{path} --version", log: false).strip
          UI.success("OSX Cleaner installed: #{version}")
        end
      end
    end
  end
end
