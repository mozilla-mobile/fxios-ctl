// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import ArgumentParser
import Foundation
import Testing
@testable import fxios

@Suite("Nimbus Tests", .serialized)
struct NimbusTests {
    func createValidRepo() throws -> URL {
        let repoDir = try createTempGitRepo()
        let markerPath = repoDir.appendingPathComponent(Configuration.markerFileName)
        try "project: firefox-ios".write(to: markerPath, atomically: true, encoding: .utf8)
        return repoDir
    }

    func setupNimbusStructure(in repoDir: URL) throws {
        // Create the firefox-ios directory structure
        let firefoxDir = repoDir.appendingPathComponent("firefox-ios")
        let nimbusDir = firefoxDir.appendingPathComponent("nimbus-features")
        try FileManager.default.createDirectory(at: nimbusDir, withIntermediateDirectories: true)

        // Create nimbus.fml.yaml
        let fmlContent = """
            ---
            about:
              description: Firefox for iOS
            include:
            """
        let fmlFile = firefoxDir.appendingPathComponent("nimbus.fml.yaml")
        try fmlContent.write(to: fmlFile, atomically: true, encoding: .utf8)
    }

    func setupSwiftFiles(in repoDir: URL) throws {
        // Create the Client directory structure
        let clientDir = repoDir.appendingPathComponent("firefox-ios/Client")
        let featureFlagsDir = clientDir.appendingPathComponent("FeatureFlags")
        let nimbusDir = clientDir.appendingPathComponent("Nimbus")
        let debugDir = clientDir.appendingPathComponent("Frontend/Settings/Main/Debug/FeatureFlags")

        try FileManager.default.createDirectory(at: featureFlagsDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: nimbusDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: debugDir, withIntermediateDirectories: true)

        // Create FeatureFlagID.swift
        let flaggableFeatureContent = """
            enum FeatureFlagID: String, CaseIterable {
                case alpha
                case zeta

                var debugKey: String? {
                    switch self {
                    case    .alpha,
                            .zeta:
                        return rawValue + PrefsKeys.FeatureFlags.DebugSuffixKey
                    default:
                        return nil
                    }
                }
            }

            struct NimbusFlaggableFeature {
                private var featureKey: String? {
                    typealias FlagKeys = PrefsKeys.FeatureFlags

                    switch featureID {
                    case .alpha:
                        return FlagKeys.Alpha
                    // Cases where users do not have the option to manipulate a setting.
                    case .zeta:
                        return nil
                    }
                }
            }
            """
        let flaggableFeaturePath = featureFlagsDir.appendingPathComponent("FeatureFlagID.swift")
        try flaggableFeatureContent.write(to: flaggableFeaturePath, atomically: true, encoding: .utf8)

        // Create NimbusFeatureFlagLayer.swift
        let flagLayerContent = """
            final class NimbusFeatureFlagLayer {
                public func checkNimbusConfigFor(
                    _ featureID: FeatureFlagID,
                    from nimbus: FxNimbus = FxNimbus.shared
                ) -> Bool {
                    switch featureID {
                    case .alpha:
                        return checkAlphaFeature(from: nimbus)

                    case .zeta:
                        return checkZetaFeature(from: nimbus)
                    }
                }

                private func checkAlphaFeature(from nimbus: FxNimbus) -> Bool {
                    return nimbus.features.alpha.value().enabled
                }

                private func checkZetaFeature(from nimbus: FxNimbus) -> Bool {
                    return nimbus.features.zeta.value().enabled
                }
            }
            """
        let flagLayerPath = nimbusDir.appendingPathComponent("NimbusFeatureFlagLayer.swift")
        try flagLayerContent.write(to: flagLayerPath, atomically: true, encoding: .utf8)

        // Create FeatureFlagsDebugViewController.swift
        let debugVCContent = """
            final class FeatureFlagsDebugViewController {
                private func generateFeatureFlagToggleSettings() -> SettingSection {
                    var children: [Setting] =  [
                        FeatureFlagsBoolSetting(
                            with: .alpha,
                            titleText: format(string: "Alpha"),
                            statusText: format(string: "Toggle Alpha")
                        ) { [weak self] _ in
                            self?.reloadView()
                        },
                        FeatureFlagsBoolSetting(
                            with: .zeta,
                            titleText: format(string: "Zeta"),
                            statusText: format(string: "Toggle Zeta")
                        ) { [weak self] _ in
                            self?.reloadView()
                        },
                    ]

                    #if canImport(FoundationModels)
                    // conditional code
                    #endif

                    return SettingSection(children: children)
                }
            }
            """
        let debugVCPath = debugDir.appendingPathComponent("FeatureFlagsDebugViewController.swift")
        try debugVCContent.write(to: debugVCPath, atomically: true, encoding: .utf8)
    }

    // MARK: - Command Configuration Tests

    @Test("Command has non-empty abstract")
    func commandHasAbstract() {
        let abstract = Nimbus.configuration.abstract
        #expect(!abstract.isEmpty)
    }

    @Test("Command has discussion text")
    func commandHasDiscussion() {
        let discussion = Nimbus.configuration.discussion
        #expect(!discussion.isEmpty)
    }

    @Test("Command has subcommands")
    func commandHasSubcommands() {
        let subcommands = Nimbus.configuration.subcommands
        #expect(subcommands.count == 4)
    }

    // MARK: - List Features Subcommand Tests

    @Test("list-features throws when not in firefox-ios repo")
    func listFeaturesThrowsWhenNotInRepo() throws {
        let tempDir = try createTempDirectory()
        defer { cleanup(tempDir) }

        let originalDir = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(tempDir.path)
        defer { FileManager.default.changeCurrentDirectoryPath(originalDir) }

        var command = try Nimbus.ListFeatures.parse([])

        #expect(throws: RepoDetectorError.self) {
            try command.run()
        }
    }

    @Test("list-features lists flat feature files alphabetically")
    func listFeaturesListsFlatFiles() throws {
        let repoDir = try createValidRepo()
        defer { cleanup(repoDir) }
        try setupNimbusStructure(in: repoDir)

        let featuresDir = repoDir.appendingPathComponent("firefox-ios/nimbus-features")
        try "# C".write(to: featuresDir.appendingPathComponent("cFeature.yaml"), atomically: true, encoding: .utf8)
        try "# A".write(to: featuresDir.appendingPathComponent("aFeature.yaml"), atomically: true, encoding: .utf8)
        try "# B".write(to: featuresDir.appendingPathComponent("bFeature.yaml"), atomically: true, encoding: .utf8)

        let originalDir = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(repoDir.path)
        defer { FileManager.default.changeCurrentDirectoryPath(originalDir) }

        // Command should run without throwing
        var command = try Nimbus.ListFeatures.parse([])
        try command.run()
    }

    @Test("list-features lists features from subfolders with relative paths")
    func listFeaturesListsSubfolderFiles() throws {
        let repoDir = try createValidRepo()
        defer { cleanup(repoDir) }
        try setupNimbusStructure(in: repoDir)

        let featuresDir = repoDir.appendingPathComponent("firefox-ios/nimbus-features")
        // Create a subfolder with a feature
        let subDir = featuresDir.appendingPathComponent("messaging")
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        try "# Messaging".write(to: subDir.appendingPathComponent("messageFeature.yaml"), atomically: true, encoding: .utf8)
        // And a top-level feature
        try "# Top".write(to: featuresDir.appendingPathComponent("topFeature.yaml"), atomically: true, encoding: .utf8)

        let originalDir = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(repoDir.path)
        defer { FileManager.default.changeCurrentDirectoryPath(originalDir) }

        var command = try Nimbus.ListFeatures.parse([])
        try command.run()
    }

    @Test("list-features handles empty nimbus-features directory")
    func listFeaturesHandlesEmptyDirectory() throws {
        let repoDir = try createValidRepo()
        defer { cleanup(repoDir) }
        try setupNimbusStructure(in: repoDir)

        let originalDir = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(repoDir.path)
        defer { FileManager.default.changeCurrentDirectoryPath(originalDir) }

        var command = try Nimbus.ListFeatures.parse([])
        try command.run()
    }

    // MARK: - Refresh Subcommand Tests

    @Test("refresh throws when not in firefox-ios repo")
    func refreshThrowsWhenNotInRepo() throws {
        let tempDir = try createTempDirectory()
        defer { cleanup(tempDir) }

        let originalDir = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(tempDir.path)
        defer { FileManager.default.changeCurrentDirectoryPath(originalDir) }

        var command = try Nimbus.Refresh.parse([])

        #expect(throws: RepoDetectorError.self) {
            try command.run()
        }
    }

    @Test("refresh command updates nimbus.fml.yaml include block")
    func refreshCommandUpdatesInclude() throws {
        let repoDir = try createValidRepo()
        defer { cleanup(repoDir) }
        try setupNimbusStructure(in: repoDir)

        // Add a feature file
        let featuresDir = repoDir.appendingPathComponent("firefox-ios/nimbus-features")
        let featureFile = featuresDir.appendingPathComponent("testFeature.yaml")
        try "# Test feature".write(to: featureFile, atomically: true, encoding: .utf8)

        let originalDir = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(repoDir.path)
        defer { FileManager.default.changeCurrentDirectoryPath(originalDir) }

        var command = try Nimbus.Refresh.parse([])
        try command.run()

        // Verify the FML was updated
        let fmlFile = repoDir.appendingPathComponent("firefox-ios/nimbus.fml.yaml")
        let content = try String(contentsOf: fmlFile, encoding: .utf8)
        #expect(content.contains("nimbus-features/testFeature.yaml"))
    }

    @Test("refresh command includes multiple feature files alphabetically")
    func refreshCommandSortsFiles() throws {
        let repoDir = try createValidRepo()
        defer { cleanup(repoDir) }
        try setupNimbusStructure(in: repoDir)

        // Add multiple feature files
        let featuresDir = repoDir.appendingPathComponent("firefox-ios/nimbus-features")
        try "# Feature C".write(to: featuresDir.appendingPathComponent("cFeature.yaml"), atomically: true, encoding: .utf8)
        try "# Feature A".write(to: featuresDir.appendingPathComponent("aFeature.yaml"), atomically: true, encoding: .utf8)
        try "# Feature B".write(to: featuresDir.appendingPathComponent("bFeature.yaml"), atomically: true, encoding: .utf8)

        let originalDir = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(repoDir.path)
        defer { FileManager.default.changeCurrentDirectoryPath(originalDir) }

        var command = try Nimbus.Refresh.parse([])
        try command.run()

        let fmlFile = repoDir.appendingPathComponent("firefox-ios/nimbus.fml.yaml")
        let content = try String(contentsOf: fmlFile, encoding: .utf8)

        // All files should be present
        #expect(content.contains("aFeature.yaml"))
        #expect(content.contains("bFeature.yaml"))
        #expect(content.contains("cFeature.yaml"))
    }

    @Test("refresh throws when nimbus.fml.yaml not found")
    func refreshThrowsWhenFmlMissing() throws {
        let repoDir = try createValidRepo()
        defer { cleanup(repoDir) }

        // Create nimbus-features dir but not the FML file
        let nimbusDir = repoDir.appendingPathComponent("firefox-ios/nimbus-features")
        try FileManager.default.createDirectory(at: nimbusDir, withIntermediateDirectories: true)

        let originalDir = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(repoDir.path)
        defer { FileManager.default.changeCurrentDirectoryPath(originalDir) }

        var command = try Nimbus.Refresh.parse([])

        #expect(throws: ValidationError.self) {
            try command.run()
        }
    }

    // MARK: - Add Subcommand Tests

    @Test("add command creates new feature file")
    func addCommandCreatesFile() throws {
        let repoDir = try createValidRepo()
        defer { cleanup(repoDir) }
        try setupNimbusStructure(in: repoDir)
        try setupSwiftFiles(in: repoDir)

        let originalDir = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(repoDir.path)
        defer { FileManager.default.changeCurrentDirectoryPath(originalDir) }

        var command = try Nimbus.Add.parse(["myTest"])
        try command.run()

        // Verify file was created with "Feature" suffix appended
        let newFile = repoDir.appendingPathComponent("firefox-ios/nimbus-features/myTestFeature.yaml")
        #expect(FileManager.default.fileExists(atPath: newFile.path))
    }

    @Test("add command appends Feature if not present")
    func addCommandAppendsFeatureSuffix() throws {
        let repoDir = try createValidRepo()
        defer { cleanup(repoDir) }
        try setupNimbusStructure(in: repoDir)
        try setupSwiftFiles(in: repoDir)

        let originalDir = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(repoDir.path)
        defer { FileManager.default.changeCurrentDirectoryPath(originalDir) }

        var command = try Nimbus.Add.parse(["myTest"])
        try command.run()

        let newFile = repoDir.appendingPathComponent("firefox-ios/nimbus-features/myTestFeature.yaml")
        #expect(FileManager.default.fileExists(atPath: newFile.path))
    }

    @Test("add command does not double-append Feature")
    func addCommandDoesNotDoubleAppendFeature() throws {
        let repoDir = try createValidRepo()
        defer { cleanup(repoDir) }
        try setupNimbusStructure(in: repoDir)
        try setupSwiftFiles(in: repoDir)

        let originalDir = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(repoDir.path)
        defer { FileManager.default.changeCurrentDirectoryPath(originalDir) }

        var command = try Nimbus.Add.parse(["myTestFeature"])
        try command.run()

        // Should be myTestFeature.yaml, not myTestFeatureFeature.yaml
        let correctFile = repoDir.appendingPathComponent("firefox-ios/nimbus-features/myTestFeature.yaml")
        let wrongFile = repoDir.appendingPathComponent("firefox-ios/nimbus-features/myTestFeatureFeature.yaml")
        #expect(FileManager.default.fileExists(atPath: correctFile.path))
        #expect(!FileManager.default.fileExists(atPath: wrongFile.path))
    }

    @Test("add command creates file with correct template")
    func addCommandCreatesTemplate() throws {
        let repoDir = try createValidRepo()
        defer { cleanup(repoDir) }
        try setupNimbusStructure(in: repoDir)
        try setupSwiftFiles(in: repoDir)

        let originalDir = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(repoDir.path)
        defer { FileManager.default.changeCurrentDirectoryPath(originalDir) }

        var command = try Nimbus.Add.parse(["test"])
        try command.run()

        // "test" gets "Feature" appended, so filename is "testFeature.yaml"
        let newFile = repoDir.appendingPathComponent("firefox-ios/nimbus-features/testFeature.yaml")
        let content = try String(contentsOf: newFile, encoding: .utf8)

        #expect(content.contains("features:"))
        #expect(content.contains("description:"))
        #expect(content.contains("variables:"))
        #expect(content.contains("defaults:"))
    }

    @Test("add command uses kebab-case for feature identifier")
    func addCommandUsesKebabCase() throws {
        let repoDir = try createValidRepo()
        defer { cleanup(repoDir) }
        try setupNimbusStructure(in: repoDir)
        try setupSwiftFiles(in: repoDir)

        let originalDir = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(repoDir.path)
        defer { FileManager.default.changeCurrentDirectoryPath(originalDir) }

        var command = try Nimbus.Add.parse(["myAwesomeTest"])
        try command.run()

        let newFile = repoDir.appendingPathComponent("firefox-ios/nimbus-features/myAwesomeTestFeature.yaml")
        let content = try String(contentsOf: newFile, encoding: .utf8)

        // The feature identifier should be kebab-case
        #expect(content.contains("my-awesome-test-feature:"))
    }

    @Test("add command updates nimbus.fml.yaml after adding")
    func addCommandUpdatesFml() throws {
        let repoDir = try createValidRepo()
        defer { cleanup(repoDir) }
        try setupNimbusStructure(in: repoDir)
        try setupSwiftFiles(in: repoDir)

        let originalDir = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(repoDir.path)
        defer { FileManager.default.changeCurrentDirectoryPath(originalDir) }

        var command = try Nimbus.Add.parse(["new"])
        try command.run()

        let fmlFile = repoDir.appendingPathComponent("firefox-ios/nimbus.fml.yaml")
        let content = try String(contentsOf: fmlFile, encoding: .utf8)
        // "new" gets "Feature" appended, so filename is "newFeature.yaml"
        #expect(content.contains("nimbus-features/newFeature.yaml"))
    }

    @Test("add command updates FeatureFlagID.swift")
    func addCommandUpdatesFlaggableFeature() throws {
        let repoDir = try createValidRepo()
        defer { cleanup(repoDir) }
        try setupNimbusStructure(in: repoDir)
        try setupSwiftFiles(in: repoDir)

        let originalDir = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(repoDir.path)
        defer { FileManager.default.changeCurrentDirectoryPath(originalDir) }

        var command = try Nimbus.Add.parse(["beta"])
        try command.run()

        let filePath = repoDir.appendingPathComponent("firefox-ios/Client/FeatureFlags/FeatureFlagID.swift")
        let content = try String(contentsOf: filePath, encoding: .utf8)

        // Should have added the enum case
        #expect(content.contains("case beta"))
        // Should have added to the default case in featureKey (since no --user-toggleable)
        #expect(content.contains(".beta"))
    }

    @Test("add command updates NimbusFeatureFlagLayer.swift")
    func addCommandUpdatesFlagLayer() throws {
        let repoDir = try createValidRepo()
        defer { cleanup(repoDir) }
        try setupNimbusStructure(in: repoDir)
        try setupSwiftFiles(in: repoDir)

        let originalDir = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(repoDir.path)
        defer { FileManager.default.changeCurrentDirectoryPath(originalDir) }

        var command = try Nimbus.Add.parse(["beta"])
        try command.run()

        let filePath = repoDir.appendingPathComponent("firefox-ios/Client/Nimbus/NimbusFeatureFlagLayer.swift")
        let content = try String(contentsOf: filePath, encoding: .utf8)

        // Should have added the switch case
        #expect(content.contains("case .beta:"))
        #expect(content.contains("checkBetaFeature(from: nimbus)"))
        // Should have added the check function
        #expect(content.contains("private func checkBetaFeature(from nimbus: FxNimbus) -> Bool"))
        #expect(content.contains("nimbus.features.beta.value().enabled"))
    }

    @Test("add command with --debuggable updates debuggable settings")
    func addCommandWithDebuggableUpdatesdebuggableSettings() throws {
        let repoDir = try createValidRepo()
        defer { cleanup(repoDir) }
        try setupNimbusStructure(in: repoDir)
        try setupSwiftFiles(in: repoDir)

        let originalDir = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(repoDir.path)
        defer { FileManager.default.changeCurrentDirectoryPath(originalDir) }

        var command = try Nimbus.Add.parse(["beta", "--debuggable"])
        try command.run()

        // Check FeatureFlagID.swift for debugKey
        let flaggablePath = repoDir.appendingPathComponent("firefox-ios/Client/FeatureFlags/FeatureFlagID.swift")
        let flaggableContent = try String(contentsOf: flaggablePath, encoding: .utf8)
        #expect(flaggableContent.contains(".beta"))

        // Check FeatureFlagsDebugViewController.swift
        let debugVCPath = repoDir.appendingPathComponent(
            "firefox-ios/Client/Frontend/Settings/Main/Debug/FeatureFlags/FeatureFlagsDebugViewController.swift")
        let debugVCContent = try String(contentsOf: debugVCPath, encoding: .utf8)
        #expect(debugVCContent.contains("with: .beta,"))
        #expect(debugVCContent.contains("\"Beta\""))
    }

    @Test("add command with --user-toggleable adds fatalError case")
    func addCommandWithUserToggleableAddsFatalError() throws {
        let repoDir = try createValidRepo()
        defer { cleanup(repoDir) }
        try setupNimbusStructure(in: repoDir)
        try setupSwiftFiles(in: repoDir)

        let originalDir = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(repoDir.path)
        defer { FileManager.default.changeCurrentDirectoryPath(originalDir) }

        var command = try Nimbus.Add.parse(["beta", "--user-toggleable"])
        try command.run()

        let filePath = repoDir.appendingPathComponent("firefox-ios/Client/FeatureFlags/FeatureFlagID.swift")
        let content = try String(contentsOf: filePath, encoding: .utf8)

        #expect(content.contains("case .beta:"))
        #expect(content.contains("fatalError(\"Please implement a key for this feature\")"))
    }

    @Test("add command with --description adds description to template")
    func addCommandWithDescriptionAddsToTemplate() throws {
        let repoDir = try createValidRepo()
        defer { cleanup(repoDir) }
        try setupNimbusStructure(in: repoDir)
        try setupSwiftFiles(in: repoDir)

        let originalDir = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(repoDir.path)
        defer { FileManager.default.changeCurrentDirectoryPath(originalDir) }

        var command = try Nimbus.Add.parse(["beta", "--description", "This is a test feature for beta users"])
        try command.run()

        let newFile = repoDir.appendingPathComponent("firefox-ios/nimbus-features/betaFeature.yaml")
        let content = try String(contentsOf: newFile, encoding: .utf8)

        #expect(content.contains("This is a test feature for beta users"))
    }

    @Test("add command without --description uses default description")
    func addCommandWithoutDescriptionUsesDefault() throws {
        let repoDir = try createValidRepo()
        defer { cleanup(repoDir) }
        try setupNimbusStructure(in: repoDir)
        try setupSwiftFiles(in: repoDir)

        let originalDir = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(repoDir.path)
        defer { FileManager.default.changeCurrentDirectoryPath(originalDir) }

        var command = try Nimbus.Add.parse(["beta"])
        try command.run()

        let newFile = repoDir.appendingPathComponent("firefox-ios/nimbus-features/betaFeature.yaml")
        let content = try String(contentsOf: newFile, encoding: .utf8)

        #expect(content.contains("Feature description"))
    }

    @Test("add command rejects description over 100 characters")
    func addCommandRejectsLongDescription() throws {
        let repoDir = try createValidRepo()
        defer { cleanup(repoDir) }
        try setupNimbusStructure(in: repoDir)
        try setupSwiftFiles(in: repoDir)

        let originalDir = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(repoDir.path)
        defer { FileManager.default.changeCurrentDirectoryPath(originalDir) }

        let longDescription = String(repeating: "a", count: 101)
        var command = try Nimbus.Add.parse(["beta", "--description", longDescription])

        #expect(throws: ValidationError.self) {
            try command.run()
        }
    }

    @Test("add command accepts description of exactly 100 characters")
    func addCommandAccepts100CharDescription() throws {
        let repoDir = try createValidRepo()
        defer { cleanup(repoDir) }
        try setupNimbusStructure(in: repoDir)
        try setupSwiftFiles(in: repoDir)

        let originalDir = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(repoDir.path)
        defer { FileManager.default.changeCurrentDirectoryPath(originalDir) }

        let exactDescription = String(repeating: "a", count: 100)
        var command = try Nimbus.Add.parse(["beta", "--description", exactDescription])
        try command.run()

        let newFile = repoDir.appendingPathComponent("firefox-ios/nimbus-features/betaFeature.yaml")
        let content = try String(contentsOf: newFile, encoding: .utf8)

        #expect(content.contains(exactDescription))
    }

    @Test("add command rejects feature name shorter than 3 characters")
    func addCommandRejectsShortFeatureName() throws {
        let repoDir = try createValidRepo()
        defer { cleanup(repoDir) }
        try setupNimbusStructure(in: repoDir)
        try setupSwiftFiles(in: repoDir)

        let originalDir = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(repoDir.path)
        defer { FileManager.default.changeCurrentDirectoryPath(originalDir) }

        var command = try Nimbus.Add.parse(["ab"])

        #expect(throws: ValidationError.self) {
            try command.run()
        }
    }

    @Test("add command accepts feature name of exactly 3 characters")
    func addCommandAccepts3CharFeatureName() throws {
        let repoDir = try createValidRepo()
        defer { cleanup(repoDir) }
        try setupNimbusStructure(in: repoDir)
        try setupSwiftFiles(in: repoDir)

        let originalDir = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(repoDir.path)
        defer { FileManager.default.changeCurrentDirectoryPath(originalDir) }

        var command = try Nimbus.Add.parse(["abc"])
        try command.run()

        let newFile = repoDir.appendingPathComponent("firefox-ios/nimbus-features/abcFeature.yaml")
        #expect(FileManager.default.fileExists(atPath: newFile.path))
    }

    // MARK: - Remove Subcommand Tests

    @Test("remove command removes feature file")
    func removeCommandRemovesFile() throws {
        let repoDir = try createValidRepo()
        defer { cleanup(repoDir) }
        try setupNimbusStructure(in: repoDir)
        try setupSwiftFiles(in: repoDir)

        let originalDir = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(repoDir.path)
        defer { FileManager.default.changeCurrentDirectoryPath(originalDir) }

        // First add a feature
        var addCommand = try Nimbus.Add.parse(["beta"])
        try addCommand.run()

        let featureFile = repoDir.appendingPathComponent("firefox-ios/nimbus-features/betaFeature.yaml")
        #expect(FileManager.default.fileExists(atPath: featureFile.path))

        // Now remove it
        var removeCommand = try Nimbus.Remove.parse(["beta"])
        try removeCommand.run()

        #expect(!FileManager.default.fileExists(atPath: featureFile.path))
    }

    @Test("remove command removes from all Swift files")
    func removeCommandRemovesFromSwiftFiles() throws {
        let repoDir = try createValidRepo()
        defer { cleanup(repoDir) }
        try setupNimbusStructure(in: repoDir)
        try setupSwiftFiles(in: repoDir)

        let originalDir = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(repoDir.path)
        defer { FileManager.default.changeCurrentDirectoryPath(originalDir) }

        // First add a feature with --debuggable
        var addCommand = try Nimbus.Add.parse(["beta", "--debuggable"])
        try addCommand.run()

        // Verify it was added
        let flaggablePath = repoDir.appendingPathComponent("firefox-ios/Client/FeatureFlags/FeatureFlagID.swift")
        var content = try String(contentsOf: flaggablePath, encoding: .utf8)
        #expect(content.contains("case beta"))

        // Now remove it
        var removeCommand = try Nimbus.Remove.parse(["beta"])
        try removeCommand.run()

        // Check FeatureFlagID.swift
        content = try String(contentsOf: flaggablePath, encoding: .utf8)
        #expect(!content.contains("case beta"))

        // Check NimbusFeatureFlagLayer.swift
        let flagLayerPath = repoDir.appendingPathComponent("firefox-ios/Client/Nimbus/NimbusFeatureFlagLayer.swift")
        let flagLayerContent = try String(contentsOf: flagLayerPath, encoding: .utf8)
        #expect(!flagLayerContent.contains("case .beta:"))
        #expect(!flagLayerContent.contains("checkBetaFeature"))

        // Check FeatureFlagsDebugViewController.swift
        let debugVCPath = repoDir.appendingPathComponent(
            "firefox-ios/Client/Frontend/Settings/Main/Debug/FeatureFlags/FeatureFlagsDebugViewController.swift")
        let debugVCContent = try String(contentsOf: debugVCPath, encoding: .utf8)
        #expect(!debugVCContent.contains("with: .beta,"))
    }

    @Test("remove command completes with status reporting when feature not found")
    func removeCommandReportsStatusWhenNotFound() throws {
        let repoDir = try createValidRepo()
        defer { cleanup(repoDir) }
        try setupNimbusStructure(in: repoDir)
        try setupSwiftFiles(in: repoDir)

        let originalDir = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(repoDir.path)
        defer { FileManager.default.changeCurrentDirectoryPath(originalDir) }

        var command = try Nimbus.Remove.parse(["nonexistent"])

        // Command should complete without throwing - it reports status for each step
        // (failures are reported as output, not exceptions)
        try command.run()

        // Verify the Swift files weren't modified (feature didn't exist)
        let flaggablePath = repoDir.appendingPathComponent("firefox-ios/Client/FeatureFlags/FeatureFlagID.swift")
        let flaggableContent = try String(contentsOf: flaggablePath, encoding: .utf8)
        #expect(!flaggableContent.contains("nonexistent"))
    }

    // MARK: - Helper Tests

    @Test("cleanFeatureName removes Feature suffix")
    func cleanFeatureNameRemovesSuffix() {
        #expect(NimbusHelpers.cleanFeatureName("testFeature") == "test")
        #expect(NimbusHelpers.cleanFeatureName("test") == "test")
        #expect(NimbusHelpers.cleanFeatureName("myAwesomeFeature") == "myAwesome")
    }

    @Test("camelToKebabCase converts correctly")
    func camelToKebabCaseConverts() {
        #expect(NimbusHelpers.camelToKebabCase("testFeature") == "test-feature")
        #expect(NimbusHelpers.camelToKebabCase("myAwesomeTest") == "my-awesome-test")
        #expect(NimbusHelpers.camelToKebabCase("simple") == "simple")
    }

    @Test("camelToTitleCase converts correctly")
    func camelToTitleCaseConverts() {
        #expect(NimbusHelpers.camelToTitleCase("testButtress") == "Test Buttress")
        #expect(NimbusHelpers.camelToTitleCase("myAwesomeFeature") == "My Awesome Feature")
        #expect(NimbusHelpers.camelToTitleCase("simple") == "Simple")
    }

    @Test("capitalizeFirst capitalizes correctly")
    func capitalizeFirstCapitalizes() {
        #expect(NimbusHelpers.capitalizeFirst("test") == "Test")
        #expect(NimbusHelpers.capitalizeFirst("Test") == "Test")
        #expect(NimbusHelpers.capitalizeFirst("").isEmpty)
    }
}
