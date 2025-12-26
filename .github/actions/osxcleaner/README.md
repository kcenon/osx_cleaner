# OSX Cleaner GitHub Action

Automated disk cleanup for macOS CI/CD environments. This action helps prevent "No space left on device" errors during builds by cleaning up caches and temporary files.

## Usage

### Basic Usage

```yaml
- name: Cleanup disk space
  uses: kcenon/osx_cleaner/.github/actions/osxcleaner@v1
```

### Pre-Build Cleanup with Space Check

```yaml
- name: Pre-build cleanup
  uses: kcenon/osx_cleaner/.github/actions/osxcleaner@v1
  with:
    level: 'normal'
    min-space: '20'  # Only cleanup if less than 20GB available
```

### Post-Build Deep Cleanup

```yaml
- name: Post-build cleanup
  uses: kcenon/osx_cleaner/.github/actions/osxcleaner@v1
  with:
    level: 'deep'
    target: 'developer'
```

### Dry Run (Preview Mode)

```yaml
- name: Preview cleanup
  uses: kcenon/osx_cleaner/.github/actions/osxcleaner@v1
  with:
    dry-run: 'true'
```

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `level` | Cleanup level: `light`, `normal`, `deep` | No | `normal` |
| `target` | Cleanup target: `browser`, `developer`, `logs`, `all` | No | `all` |
| `min-space` | Minimum available space threshold in specified unit | No | - |
| `min-space-unit` | Unit for min-space: `mb`, `gb`, `tb` | No | `gb` |
| `dry-run` | Preview mode without actual deletion | No | `false` |
| `version` | OSX Cleaner version to use | No | `latest` |

## Outputs

| Output | Description |
|--------|-------------|
| `status` | Cleanup status: `success`, `skipped`, `completed_with_errors` |
| `freed-space` | Amount of space freed in bytes |
| `freed-formatted` | Amount of space freed (human readable) |
| `files-removed` | Number of files removed |
| `duration-ms` | Cleanup duration in milliseconds |
| `available-before` | Available disk space before cleanup (bytes) |
| `available-after` | Available disk space after cleanup (bytes) |

## Example Workflow

```yaml
name: Build

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  build:
    runs-on: macos-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Pre-build cleanup
        id: pre-cleanup
        uses: kcenon/osx_cleaner/.github/actions/osxcleaner@v1
        with:
          level: 'normal'
          min-space: '20'

      - name: Build
        run: |
          echo "Available space: ${{ steps.pre-cleanup.outputs.freed-formatted }} freed"
          xcodebuild -scheme MyApp -destination 'platform=macOS'

      - name: Post-build deep cleanup
        uses: kcenon/osx_cleaner/.github/actions/osxcleaner@v1
        with:
          level: 'deep'
          target: 'developer'
```

## Cleanup Levels

| Level | Description | Safe for CI |
|-------|-------------|-------------|
| `light` | Only clearly safe caches | Yes |
| `normal` | Standard cleanup including browser caches | Yes |
| `deep` | Aggressive cleanup including Xcode DerivedData | Yes |

## Cleanup Targets

| Target | What it cleans |
|--------|----------------|
| `browser` | Safari, Chrome, Firefox caches |
| `developer` | Xcode DerivedData, npm cache, Cargo cache, etc. |
| `logs` | System and application logs |
| `all` | All of the above |

## Notes

- The action runs in `--non-interactive` mode suitable for CI/CD
- JSON output is automatically parsed and exposed as action outputs
- A summary is added to the GitHub Actions workflow summary
- If `min-space` is set and available space exceeds the threshold, cleanup is skipped
