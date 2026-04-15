// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import ArgumentParser
import Foundation

extension Nimbus {
    struct Remove: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Remove a Nimbus feature flag.",
            discussion: """
                Removes a feature from all locations where it was added.

                Each removal step reports success or failure. If a step fails,
                you may need to manually remove the feature from that location.
                """
        )

        @Argument(help: "The feature name in camelCase (without 'Feature' suffix).")
        var featureName: String

        mutating func run() throws {
            let repo = try RepoDetector.requireValidRepo()

            // Standardize the feature name
            let cleanName = NimbusHelpers.cleanFeatureName(featureName)

            Herald.declare("Removing feature '\(cleanName)'...", isNewCommand: true)
            Herald.declare("")

            // Collect all file paths
            let yamlFileName = "\(cleanName)Feature.yaml"
            let yamlFilePath = repo.root
                .appendingPathComponent(NimbusConstants.nimbusFeaturesPath)
                .appendingPathComponent(yamlFileName)
            let flaggableFeaturePath = repo.root.appendingPathComponent(NimbusConstants.nimbusFlaggableFeaturePath)
            let flagLayerPath = repo.root.appendingPathComponent(NimbusConstants.nimbusFeatureFlagLayerPath)
            let debugVCPath = repo.root.appendingPathComponent(NimbusConstants.featureFlagsDebugViewControllerPath)

            var hasFailures = false

            // 1. Remove YAML file
            Herald.declare("Removing \(yamlFileName)...")
            if FileManager.default.fileExists(atPath: yamlFilePath.path) {
                do {
                    try FileManager.default.removeItem(at: yamlFilePath)
                    reportSuccess("Removed YAML file")
                } catch {
                    reportFailure("Failed to remove YAML file: \(error.localizedDescription)")
                    hasFailures = true
                }
            } else {
                reportSkipped("YAML file not found (already removed?)")
            }

            // 2. Update nimbus.fml.yaml
            Herald.declare("Updating nimbus.fml.yaml...")
            do {
                try NimbusHelpers.updateNimbusFml(repoRoot: repo.root)
                reportSuccess("Updated nimbus.fml.yaml")
            } catch {
                reportFailure("Failed to update nimbus.fml.yaml: \(error.localizedDescription)")
                hasFailures = true
            }

            // 3. Remove from NimbusFlaggableFeature.swift
            hasFailures = removeFlaggableFeature(cleanName, from: flaggableFeaturePath) || hasFailures

            // 4. Remove from NimbusFeatureFlagLayer.swift
            Herald.declare("Updating NimbusFeatureFlagLayer.swift...")
            if FileManager.default.fileExists(atPath: flagLayerPath.path) {
                do {
                    let result = try NimbusFeatureFlagLayerEditor.removeFeature(
                        name: cleanName,
                        filePath: flagLayerPath
                    )

                    if result.switchCaseRemoved {
                        reportSuccess("Removed switch case")
                    } else {
                        reportFailure("Could not find switch case 'case .\(cleanName):'")
                        hasFailures = true
                    }

                    let funcName = "check\(StringUtils.capitalizeFirst(cleanName))Feature"
                    if result.checkFunctionRemoved {
                        reportSuccess("Removed \(funcName)")
                    } else {
                        reportFailure("Could not find function '\(funcName)'")
                        hasFailures = true
                    }
                } catch {
                    reportFailure("Failed to process file: \(error.localizedDescription)")
                    hasFailures = true
                }
            } else {
                reportFailure("File not found")
                hasFailures = true
            }

            // 5. Remove from FeatureFlagsDebugViewController.swift (optional)
            Herald.declare("Updating FeatureFlagsDebugViewController.swift...")
            if FileManager.default.fileExists(atPath: debugVCPath.path) {
                do {
                    let result = try FeatureFlagsDebugViewControllerEditor.removeFeature(
                        name: cleanName,
                        filePath: debugVCPath
                    )

                    if !result.wasPresent {
                        reportSkipped("Feature not in debuggable settings (not added with --debuggable)")
                    } else if result.removed {
                        reportSuccess("Removed debug setting")
                    } else {
                        reportFailure("Found but could not remove debug setting block")
                        hasFailures = true
                    }
                } catch {
                    reportFailure("Failed to process file: \(error.localizedDescription)")
                    hasFailures = true
                }
            } else {
                reportSkipped("File not found (debug settings may not exist)")
            }

            // Summary
            Herald.declare("")
            if hasFailures {
                // swiftlint:disable:next line_length
                Herald.declare("Removal completed with errors. Please check the items marked as FAILED above and remove them manually.", asError: true, asConclusion: true)
            } else {
                Herald.declare("Successfully removed feature '\(cleanName)'", asConclusion: true)
            }
        }

        // MARK: - Helpers

        /// Removes the feature from NimbusFlaggableFeature.swift. Returns true if any failures occurred.
        private func removeFlaggableFeature(_ name: String, from path: URL) -> Bool {
            Herald.declare("Updating FeatureFlagID.swift...")
            var hasFailures = false

            guard FileManager.default.fileExists(atPath: path.path) else {
                reportFailure("File not found")
                return true
            }

            do {
                let result = try NimbusFlaggableFeatureEditor.removeFeature(name: name, filePath: path)

                if result.enumCaseRemoved {
                    reportSuccess("Removed enum case")
                } else {
                    reportFailure("Could not find enum case 'case \(name)'")
                    hasFailures = true
                }

                if let debugKeyRemoved = result.debugKeyRemoved {
                    if debugKeyRemoved {
                        reportSuccess("Removed from debugKey")
                    } else {
                        reportFailure("Found in debugKey but could not remove")
                        hasFailures = true
                    }
                }

                if result.featureKeyRemoved {
                    reportSuccess("Removed from featureKey")
                } else {
                    reportFailure("Could not find/remove from featureKey")
                    hasFailures = true
                }
            } catch {
                reportFailure("Failed to process file: \(error.localizedDescription)")
                hasFailures = true
            }

            return hasFailures
        }

        // MARK: - Status Reporting

        private func reportSuccess(_ message: String) {
            Herald.declare("  ✓ \(message)")
        }

        private func reportFailure(_ message: String) {
            Herald.declare("  ✗ FAILED: \(message)", asError: true)
            Herald.declare("    → You may need to remove this manually", asError: true)
        }

        private func reportSkipped(_ message: String) {
            Herald.declare("  - \(message)")
        }
    }
}
