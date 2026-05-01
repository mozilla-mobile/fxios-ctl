// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import ArgumentParser
import Foundation

struct Nimbus: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Manage Nimbus feature configuration files.",
        discussion: """
            Manages Nimbus feature flags across the firefox-ios codebase.

            Use 'list-features' to list all available features.
            Use 'refresh' to update the include block in nimbus.fml.yaml.
            Use 'add' to create a new feature with all required boilerplate.
            Use 'remove' to remove a feature from all locations.
            """,
        subcommands: [ListFeatures.self, Refresh.self, Add.self, Remove.self]
    )
}

// MARK: - Constants

// These paths are firefox-ios repo conventions, not values we discover at runtime. The Nimbus
// subcommands (add/remove/refresh) all touch this same set of files in lockstep, so if firefox-ios
// ever reorganizes the FeatureFlags or Nimbus directories these constants must be updated together.
enum NimbusConstants {
    static let nimbusFmlPath = "firefox-ios/nimbus.fml.yaml"
    static let nimbusFeaturesPath = "firefox-ios/nimbus-features"
    static let nimbusFlaggableFeaturePath = "firefox-ios/Client/FeatureFlags/FeatureFlagID.swift"
    static let nimbusFeatureFlagLayerPath = "firefox-ios/Client/Nimbus/NimbusFeatureFlagLayer.swift"
    // swiftlint:disable:next line_length
    static let featureFlagsDebugViewControllerPath = "firefox-ios/Client/Frontend/Settings/Main/Debug/FeatureFlags/FeatureFlagsDebugViewController.swift"
}
