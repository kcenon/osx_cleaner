# OSX Cleaner Jenkins Pipeline Shared Library

Integrate OSX Cleaner into your Jenkins pipelines for automated disk cleanup on macOS build agents.

## Setup

### 1. Add Shared Library to Jenkins

1. Go to **Manage Jenkins** → **Configure System**
2. Scroll to **Global Pipeline Libraries**
3. Add a new library:
   - **Name**: `osxcleaner`
   - **Default version**: `main`
   - **Retrieval method**: Modern SCM
   - **Source Code Management**: Git
   - **Project Repository**: `https://github.com/kcenon/osx_cleaner.git`
   - **Library Path**: `integrations/jenkins`

### 2. Use in Jenkinsfile

```groovy
@Library('osxcleaner') _

pipeline {
    agent { label 'macos' }

    stages {
        stage('Pre-build Cleanup') {
            steps {
                osxcleanerPreBuild()
            }
        }

        stage('Build') {
            steps {
                sh 'xcodebuild -scheme MyApp -destination "platform=macOS"'
            }
        }

        stage('Post-build Cleanup') {
            steps {
                osxcleanerPostBuild()
            }
        }
    }
}
```

## Available Functions

### `osxcleaner(config)`

Main cleanup function with full configuration options.

**Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `level` | String | `'normal'` | Cleanup level: `light`, `normal`, `deep` |
| `target` | String | `'all'` | Cleanup target: `browser`, `developer`, `logs`, `all` |
| `minSpace` | Integer | `null` | Minimum space threshold (cleanup if below) |
| `minSpaceUnit` | String | `'gb'` | Unit for minSpace: `mb`, `gb`, `tb` |
| `dryRun` | Boolean | `false` | Preview mode without actual deletion |
| `version` | String | `'latest'` | OSX Cleaner version to use |
| `failOnError` | Boolean | `false` | Fail build on cleanup error |

**Returns:** Map with cleanup results

```groovy
def result = osxcleaner(level: 'deep', target: 'developer')
echo "Freed: ${result.freedFormatted}"
```

### `osxcleanerPreBuild(config)`

Pre-configured for pre-build cleanup. Defaults:
- Level: `normal`
- Target: `developer`
- MinSpace: `20` GB

```groovy
osxcleanerPreBuild()
// or with custom threshold
osxcleanerPreBuild(minSpace: 30)
```

### `osxcleanerPostBuild(config)`

Pre-configured for post-build cleanup. Defaults:
- Level: `deep`
- Target: `all`

```groovy
osxcleanerPostBuild()
// or with custom level
osxcleanerPostBuild(level: 'normal')
```

## Example Pipelines

### Basic Cleanup

```groovy
@Library('osxcleaner') _

pipeline {
    agent { label 'macos' }

    stages {
        stage('Cleanup') {
            steps {
                osxcleaner()
            }
        }
    }
}
```

### Conditional Cleanup

```groovy
@Library('osxcleaner') _

pipeline {
    agent { label 'macos' }

    stages {
        stage('Conditional Cleanup') {
            steps {
                script {
                    def result = osxcleaner(
                        level: 'normal',
                        minSpace: 50,
                        minSpaceUnit: 'gb'
                    )

                    if (result.status == 'skipped') {
                        echo "Cleanup skipped - sufficient space available"
                    } else {
                        echo "Freed ${result.freedFormatted}"
                    }
                }
            }
        }
    }
}
```

### Dry Run Preview

```groovy
@Library('osxcleaner') _

pipeline {
    agent { label 'macos' }

    stages {
        stage('Preview Cleanup') {
            steps {
                script {
                    def preview = osxcleaner(dryRun: true, level: 'deep')
                    echo "Would free: ${preview.freedFormatted}"
                }
            }
        }
    }
}
```

### Full Build Pipeline

```groovy
@Library('osxcleaner') _

pipeline {
    agent { label 'macos' }

    options {
        timeout(time: 1, unit: 'HOURS')
    }

    stages {
        stage('Pre-build') {
            steps {
                script {
                    def cleanup = osxcleanerPreBuild(minSpace: 25)
                    echo "Pre-build cleanup: ${cleanup.status}"
                }
            }
        }

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build') {
            steps {
                sh 'swift build -c release'
            }
        }

        stage('Test') {
            steps {
                sh 'swift test'
            }
        }

        stage('Archive') {
            steps {
                archiveArtifacts artifacts: '.build/release/*'
            }
        }
    }

    post {
        always {
            osxcleanerPostBuild()
        }
    }
}
```

## Result Object

The cleanup functions return a Map with the following keys:

| Key | Type | Description |
|-----|------|-------------|
| `status` | String | `success`, `skipped`, `error` |
| `freedBytes` | Long | Bytes freed |
| `freedFormatted` | String | Human-readable freed space |
| `filesRemoved` | Integer | Number of files removed |
| `durationMs` | Long | Cleanup duration in milliseconds |
| `availableBefore` | Long | Available space before cleanup |
| `availableAfter` | Long | Available space after cleanup |

## Notes

- The library automatically skips cleanup on non-macOS agents
- OSX Cleaner is installed automatically if not present
- JSON output is parsed for structured results
- Cleanup failures are logged but don't fail the build by default
