// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Foundation

enum Configuration {
    static let name = "fxios"
    static let version = "20260220.0"
    static let shortDescription = "A helper CLI for the firefox-ios repository"
    static let markerFileName = ".fxios.yaml"

    static var aboutText: String {
        """
        \(name) v\(version)

        `fxios` provides a single entry point for the running of common tasks,
        automations, and workflows used in the development of mozilla-mobile/firefox-ios.

        originally authored by @adudenamedruby
        """
    }
}

/// Bundled default values that are merged with project configuration.
/// Project config (.fxios.yaml) takes precedence over these defaults.
enum DefaultConfig {
    static let defaultBootstrap = "firefox"
    static let defaultBuildProduct = "firefox"
}
