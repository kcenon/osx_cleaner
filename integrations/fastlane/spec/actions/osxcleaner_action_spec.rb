# SPDX-License-Identifier: BSD-3-Clause
# Copyright (c) 2021-2025

require 'spec_helper'

RSpec.describe Fastlane::Actions::OsxcleanerAction do
  describe '#run' do
    let(:helper) { Fastlane::Helper::OsxcleanerHelper }
    let(:mock_output) do
      '{"status":"success","freed_bytes":1073741824,"freed_formatted":"1.00 GB","files_removed":42,"duration_ms":1234}'
    end

    before do
      allow(helper).to receive(:osxcleaner_path).and_return('/usr/local/bin/osxcleaner')
      allow(Fastlane::Actions).to receive(:sh).and_return(mock_output)
    end

    it 'runs cleanup with default parameters' do
      expect(Fastlane::Actions).to receive(:sh).with(
        /osxcleaner clean --non-interactive --format json --level normal --target all/,
        hash_including(log: false)
      )

      result = described_class.run({
        level: 'normal',
        target: 'all',
        dry_run: false,
        version: 'latest'
      })

      expect(result[:status]).to eq('success')
      expect(result[:freed_bytes]).to eq(1_073_741_824)
      expect(result[:files_removed]).to eq(42)
    end

    it 'includes dry-run flag when specified' do
      expect(Fastlane::Actions).to receive(:sh).with(
        /--dry-run/,
        hash_including(log: false)
      )

      described_class.run({
        level: 'normal',
        target: 'all',
        dry_run: true,
        version: 'latest'
      })
    end

    it 'includes min-space parameters when specified' do
      expect(Fastlane::Actions).to receive(:sh).with(
        /--min-space 20 --min-space-unit gb/,
        hash_including(log: false)
      )

      described_class.run({
        level: 'normal',
        target: 'all',
        min_space: 20,
        min_space_unit: 'gb',
        dry_run: false,
        version: 'latest'
      })
    end
  end

  describe '.is_supported?' do
    it 'returns true for mac platform' do
      expect(described_class.is_supported?(:mac)).to be true
    end

    it 'returns false for ios platform' do
      expect(described_class.is_supported?(:ios)).to be false
    end

    it 'returns false for android platform' do
      expect(described_class.is_supported?(:android)).to be false
    end
  end

  describe '.available_options' do
    it 'defines all expected options' do
      options = described_class.available_options
      option_keys = options.map(&:key)

      expect(option_keys).to include(:level)
      expect(option_keys).to include(:target)
      expect(option_keys).to include(:min_space)
      expect(option_keys).to include(:min_space_unit)
      expect(option_keys).to include(:dry_run)
      expect(option_keys).to include(:version)
    end

    it 'has valid default values' do
      options = described_class.available_options
      level_option = options.find { |o| o.key == :level }
      target_option = options.find { |o| o.key == :target }

      expect(level_option.default_value).to eq('normal')
      expect(target_option.default_value).to eq('all')
    end
  end

  describe '.category' do
    it 'returns :building' do
      expect(described_class.category).to eq(:building)
    end
  end
end
