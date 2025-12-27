// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025

/**
 * Pre-build cleanup helper
 *
 * Usage in Jenkinsfile:
 *   @Library('osxcleaner') _
 *   osxcleanerPreBuild()
 */

def call(Map config = [:]) {
    def defaultConfig = [
        level: 'normal',
        target: 'developer',
        minSpace: 20,
        minSpaceUnit: 'gb',
        dryRun: false
    ]

    def mergedConfig = defaultConfig + config

    echo "Running pre-build cleanup (min ${mergedConfig.minSpace}${mergedConfig.minSpaceUnit} required)..."

    return osxcleaner(mergedConfig)
}
