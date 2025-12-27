// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025

/**
 * Post-build cleanup helper
 *
 * Usage in Jenkinsfile:
 *   @Library('osxcleaner') _
 *   osxcleanerPostBuild()
 */

def call(Map config = [:]) {
    def defaultConfig = [
        level: 'deep',
        target: 'all',
        dryRun: false
    ]

    def mergedConfig = defaultConfig + config

    echo "Running post-build deep cleanup..."

    return osxcleaner(mergedConfig)
}
