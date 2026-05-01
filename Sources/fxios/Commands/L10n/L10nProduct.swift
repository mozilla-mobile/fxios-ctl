// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import ArgumentParser

/// Product presets for l10n commands, providing default configuration values.
enum L10nProduct: String, ExpressibleByArgument, CaseIterable {
    case firefox
    case focus

    var xliffName: String {
        switch self {
        case .firefox: return "firefox-ios.xliff"
        case .focus: return "focus-ios.xliff"
        }
    }

    var exportBasePath: String {
        switch self {
        case .firefox: return "/tmp/ios-localization"
        case .focus: return "/tmp/ios-localization-focus"
        }
    }

    var developmentRegion: String {
        switch self {
        case .firefox: return "en-US"
        case .focus: return "en"
        }
    }

    var projectName: String {
        switch self {
        case .firefox: return "Client.xcodeproj"
        case .focus: return "Blockzilla.xcodeproj"
        }
    }

    /// Relative path from repo root to .xcodeproj
    var projectPath: String {
        switch self {
        case .firefox: return "firefox-ios/Client.xcodeproj"
        case .focus: return "focus-ios/Blockzilla.xcodeproj"
        }
    }

    var skipWidgetKit: Bool {
        switch self {
        case .firefox: return false
        case .focus: return true
        }
    }
}
