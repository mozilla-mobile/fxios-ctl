// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import ArgumentParser
import Foundation

// Two product enums live here on purpose. They serve different command groups and
// carry different configuration, so keeping them as siblings makes the choice obvious:
// - BuildProduct: used by `build`, `run`, `test`, `clean` (Xcode schemes, configurations, bundle IDs)
// - L10nProduct:  used by `l10n export`, `l10n import`, `l10n templates` (xliff names, Pontoon paths)

// MARK: - Build Product

/// Represents the available products that can be built, run, or tested
enum BuildProduct: String, ExpressibleByArgument, CaseIterable {
    case firefox
    case focus
    case klar

    var scheme: String {
        switch self {
        case .firefox: return "Fennec"
        case .focus: return "Focus"
        case .klar: return "Klar"
        }
    }

    var projectPath: String {
        switch self {
        case .firefox: return "firefox-ios/Client.xcodeproj"
        case .focus, .klar: return "focus-ios/Blockzilla.xcodeproj"
        }
    }

    var defaultConfiguration: String {
        switch self {
        case .firefox: return "Fennec"
        case .focus: return "FocusDebug"
        case .klar: return "KlarDebug"
        }
    }

    var testingConfiguration: String {
        switch self {
        case .firefox: return "Fennec_Testing"
        case .focus: return "FocusDebug"
        case .klar: return "KlarDebug"
        }
    }

    var bundleIdentifier: String {
        switch self {
        case .firefox: return "org.mozilla.ios.Fennec"
        case .focus: return "org.mozilla.ios.Focus"
        case .klar: return "org.mozilla.ios.Klar"
        }
    }
}

// MARK: - L10n Product

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
