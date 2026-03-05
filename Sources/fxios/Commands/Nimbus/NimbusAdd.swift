// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import ArgumentParser
import Foundation

extension Nimbus {
    struct Add: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Add a new Nimbus feature flag.",
            discussion: """
                Creates a new feature YAML file and adds the feature to all required Swift files.

                The feature name should be in camelCase without the 'Feature' suffix.
                For example: 'testButtress' will create 'testButtressFeature.yaml'.
                """
        )

        @Argument(help: "The feature name in camelCase (without 'Feature' suffix).")
        var featureName: String

        @Flag(name: .long, help: "Add the feature to the debuggable settings UI.")
        var debuggable = false

        @Flag(name: .long, help: "Mark the feature as user-toggleable (requires implementing a preference key).")
        var userToggleable = false

        @Option(name: .shortAndLong, help: "A short description of the feature (max 100 characters).")
        var description: String?

        mutating func run() throws {
            // Validate feature name length
            guard featureName.count >= 3 else {
                throw ValidationError("Feature name must be at least 3 characters long.")
            }

            // Validate description length if provided
            if let desc = description, desc.count > 100 {
                throw ValidationError("Description must be 100 characters or less (currently \(desc.count) characters).")
            }
            let repo = try RepoDetector.requireValidRepo()

            // Standardize the feature name (remove Feature suffix if present)
            let cleanName = NimbusHelpers.cleanFeatureName(featureName)

            Herald.declare("Adding feature '\(cleanName)'...", isNewCommand: true)

            // 1. Create the YAML file
            let yamlFileName = "\(cleanName)Feature.yaml"
            let yamlFilePath = repo.root
                .appendingPathComponent(NimbusConstants.nimbusFeaturesPath)
                .appendingPathComponent(yamlFileName)

            Herald.declare("Creating feature file: \(NimbusConstants.nimbusFeaturesPath)/\(yamlFileName)")
            try NimbusHelpers.writeFeatureTemplate(to: yamlFilePath, featureName: "\(cleanName)Feature", description: description)

            // 2. Update nimbus.fml.yaml
            Herald.declare("Updating nimbus.fml.yaml...")
            try NimbusHelpers.updateNimbusFml(repoRoot: repo.root)

            // 3. Update NimbusFlaggableFeature.swift
            let flaggableFeaturePath = repo.root.appendingPathComponent(NimbusConstants.nimbusFlaggableFeaturePath)
            Herald.declare("Updating NimbusFlaggableFeature.swift...")
            try NimbusFlaggableFeatureEditor.addFeature(
                name: cleanName,
                debug: debuggable,
                userToggleable: userToggleable,
                filePath: flaggableFeaturePath
            )

            // 4. Update NimbusFeatureFlagLayer.swift
            let flagLayerPath = repo.root.appendingPathComponent(NimbusConstants.nimbusFeatureFlagLayerPath)
            Herald.declare("Updating NimbusFeatureFlagLayer.swift...")
            try NimbusFeatureFlagLayerEditor.addFeature(name: cleanName, filePath: flagLayerPath)

            // 5. If --debuggable, update FeatureFlagsDebugViewController.swift
            if debuggable {
                let debugVCPath = repo.root.appendingPathComponent(NimbusConstants.featureFlagsDebugViewControllerPath)
                Herald.declare("Updating FeatureFlagsDebugViewController.swift...")
                try FeatureFlagsDebugViewControllerEditor.addFeature(name: cleanName, filePath: debugVCPath)
            }

            Herald.declare("Successfully added feature '\(cleanName)'", asConclusion: true)
            Herald.declare("Please remember to add this feature to the feature flag spreadsheet.")
        }
    }
}
