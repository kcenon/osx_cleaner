// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025

/**
 * OSX Cleaner Jenkins Pipeline Shared Library
 *
 * Usage in Jenkinsfile:
 *   @Library('osxcleaner') _
 *   osxcleaner(level: 'normal', target: 'all')
 */

def call(Map config = [:]) {
    def level = config.level ?: 'normal'
    def target = config.target ?: 'all'
    def minSpace = config.minSpace ?: null
    def minSpaceUnit = config.minSpaceUnit ?: 'gb'
    def dryRun = config.dryRun ?: false
    def version = config.version ?: 'latest'
    def failOnError = config.failOnError ?: false

    def result = [:]

    node {
        if (!isUnix() || !env.NODE_LABELS?.contains('macos')) {
            echo "OSX Cleaner: Skipping - not running on macOS"
            result.status = 'skipped'
            result.reason = 'not_macos'
            return result
        }

        stage('OSX Cleaner') {
            try {
                // Install OSX Cleaner
                installOsxCleaner(version)

                // Build command
                def cmd = buildCommand(level, target, minSpace, minSpaceUnit, dryRun)

                // Execute cleanup
                def output = sh(script: cmd, returnStdout: true).trim()

                // Parse JSON output
                result = parseOutput(output)

                // Log results
                logResults(result)

            } catch (Exception e) {
                result.status = 'error'
                result.error = e.message

                if (failOnError) {
                    error("OSX Cleaner failed: ${e.message}")
                } else {
                    echo "OSX Cleaner warning: ${e.message}"
                }
            }
        }
    }

    return result
}

def installOsxCleaner(String version) {
    echo "Installing OSX Cleaner..."

    if (version == 'latest' || version == 'source') {
        // Build from source
        sh '''
            if [ ! -d /tmp/osx_cleaner ]; then
                git clone --depth 1 https://github.com/kcenon/osx_cleaner.git /tmp/osx_cleaner
            fi
            cd /tmp/osx_cleaner
            git pull
            swift build -c release
            sudo cp .build/release/osxcleaner /usr/local/bin/ || cp .build/release/osxcleaner ~/bin/
        '''
    } else {
        // Try to download pre-built binary
        def downloadUrl = "https://github.com/kcenon/osx_cleaner/releases/download/${version}/osxcleaner-macos.tar.gz"

        def downloadSuccess = sh(script: """
            curl -sL --fail "${downloadUrl}" -o /tmp/osxcleaner.tar.gz 2>/dev/null
        """, returnStatus: true) == 0

        if (downloadSuccess) {
            sh '''
                tar -xzf /tmp/osxcleaner.tar.gz -C /tmp
                sudo cp /tmp/osxcleaner /usr/local/bin/ || cp /tmp/osxcleaner ~/bin/
            '''
        } else {
            echo "Pre-built binary not available, building from source..."
            installOsxCleaner('source')
        }
    }

    sh 'osxcleaner --version || ~/bin/osxcleaner --version || true'
}

def buildCommand(String level, String target, def minSpace, String minSpaceUnit, boolean dryRun) {
    def cmd = "osxcleaner clean --non-interactive --format json"
    cmd += " --level ${level}"
    cmd += " --target ${target}"

    if (minSpace) {
        cmd += " --min-space ${minSpace}"
        cmd += " --min-space-unit ${minSpaceUnit}"
    }

    if (dryRun) {
        cmd += " --dry-run"
    }

    return cmd
}

def parseOutput(String output) {
    def result = [:]

    // Find JSON line in output
    def lines = output.split('\n')
    def jsonLine = lines.find { it.startsWith('{') }

    if (jsonLine) {
        def json = readJSON(text: jsonLine)
        result.status = json.status ?: 'unknown'
        result.freedBytes = json.freed_bytes ?: 0
        result.freedFormatted = json.freed_formatted ?: '0 bytes'
        result.filesRemoved = json.files_removed ?: 0
        result.durationMs = json.duration_ms ?: 0
        result.availableBefore = json.before?.available ?: 0
        result.availableAfter = json.after?.available ?: 0
    } else {
        result.status = 'unknown'
        result.rawOutput = output
    }

    return result
}

def logResults(Map result) {
    echo """
╔════════════════════════════════════════════╗
║          OSX Cleaner Results               ║
╠════════════════════════════════════════════╣
║ Status:        ${result.status?.padRight(26)}║
║ Space Freed:   ${result.freedFormatted?.padRight(26)}║
║ Files Removed: ${result.filesRemoved?.toString()?.padRight(26)}║
║ Duration:      ${result.durationMs?.toString()?.padRight(22)} ms ║
╚════════════════════════════════════════════╝
"""
}
