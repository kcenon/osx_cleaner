# OSX Cleaner Fastlane Plugin

[![fastlane Plugin Badge](https://rawcdn.githack.com/fastlane/fastlane/master/fastlane/assets/plugin-badge.svg)](https://rubygems.org/gems/fastlane-plugin-osxcleaner)

Automated disk cleanup for macOS builds. This plugin helps prevent "No space left on device" errors during iOS/macOS builds by cleaning up caches and temporary files.

## Installation

Add the plugin to your project:

```bash
fastlane add_plugin osxcleaner
```

Or add it to your `Pluginfile`:

```ruby
gem 'fastlane-plugin-osxcleaner', git: 'https://github.com/kcenon/osx_cleaner.git', glob: 'integrations/fastlane/*.gemspec'
```

## Usage

### Basic Cleanup

```ruby
# In your Fastfile
lane :cleanup do
  osxcleaner
end
```

### Pre-Build Cleanup with Space Check

```ruby
lane :build do
  # Only cleanup if less than 20GB available
  osxcleaner(
    level: "normal",
    target: "developer",
    min_space: 20,
    min_space_unit: "gb"
  )

  # Build your app
  gym(scheme: "MyApp")
end
```

### Post-Build Deep Cleanup

```ruby
lane :release do
  gym(scheme: "MyApp")

  # Deep cleanup after build
  osxcleaner(
    level: "deep",
    target: "all"
  )
end
```

### Dry Run Preview

```ruby
lane :preview_cleanup do
  result = osxcleaner(dry_run: true)
  UI.message("Would free: #{result[:freed_formatted]}")
end
```

## Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `level` | Cleanup level: `light`, `normal`, `deep` | `normal` |
| `target` | Cleanup target: `browser`, `developer`, `logs`, `all` | `all` |
| `min_space` | Minimum space threshold in specified unit | - |
| `min_space_unit` | Unit for min_space: `mb`, `gb`, `tb` | `gb` |
| `dry_run` | Preview mode without actual deletion | `false` |
| `version` | OSX Cleaner version to install | `latest` |

## Return Value

The action returns a hash with cleanup results:

```ruby
result = osxcleaner(level: "normal")

result[:status]           # "success", "skipped", or "error"
result[:freed_bytes]      # Bytes freed (Integer)
result[:freed_formatted]  # Human-readable freed space (String)
result[:files_removed]    # Number of files removed (Integer)
result[:duration_ms]      # Cleanup duration in milliseconds (Integer)
result[:available_before] # Available space before cleanup (Integer)
result[:available_after]  # Available space after cleanup (Integer)
```

## Cleanup Levels

| Level | Description | Use Case |
|-------|-------------|----------|
| `light` | Only clearly safe caches | Quick cleanup during active development |
| `normal` | Standard cleanup including browser caches | Regular CI/CD builds |
| `deep` | Aggressive cleanup including Xcode DerivedData | Post-release cleanup |

## Cleanup Targets

| Target | What it cleans |
|--------|----------------|
| `browser` | Safari, Chrome, Firefox caches |
| `developer` | Xcode DerivedData, npm cache, Cargo cache, etc. |
| `logs` | System and application logs |
| `all` | All of the above |

## Example Fastfile

```ruby
default_platform(:mac)

platform :mac do
  before_all do
    # Pre-build cleanup with 25GB threshold
    result = osxcleaner(
      level: "normal",
      target: "developer",
      min_space: 25,
      min_space_unit: "gb"
    )

    if result[:status] == "success"
      UI.success("Freed #{result[:freed_formatted]} before build")
    end
  end

  lane :build do
    gym(scheme: "MyApp")
  end

  lane :test do
    scan(scheme: "MyApp")
  end

  lane :release do
    build
    # Upload to App Store...
  end

  after_all do |lane|
    # Post-build deep cleanup
    osxcleaner(
      level: "deep",
      target: "all"
    )
  end

  error do |lane, exception|
    # Cleanup even on error
    osxcleaner(level: "normal")
  end
end
```

## Environment Variables

You can configure defaults using environment variables:

| Variable | Description |
|----------|-------------|
| `OSXCLEANER_LEVEL` | Default cleanup level |
| `OSXCLEANER_TARGET` | Default cleanup target |
| `OSXCLEANER_MIN_SPACE` | Default minimum space threshold |
| `OSXCLEANER_MIN_SPACE_UNIT` | Default unit for min_space |
| `OSXCLEANER_DRY_RUN` | Enable dry run mode |
| `OSXCLEANER_VERSION` | OSX Cleaner version to use |

## Notes

- The plugin automatically installs OSX Cleaner if not present
- JSON output is parsed for structured results
- Works only on macOS (returns an error on other platforms)
- Cleanup failures are reported but don't fail the lane by default

## Development

```bash
# Install dependencies
bundle install

# Run tests
bundle exec rspec

# Run linter
bundle exec rubocop
```

## License

BSD-3-Clause
