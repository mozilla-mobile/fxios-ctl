// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Foundation
import Testing
@testable import fxios

@Suite("CommandHelpers Tests", .serialized)
struct CommandHelpersTests {
    // MARK: - formatCommand Tests

    @Test("formatCommand formats simple command")
    func formatCommandSimple() {
        let result = CommandHelpers.formatCommand("xcodebuild", arguments: ["-project", "Test.xcodeproj"])
        #expect(result.contains("xcodebuild"))
        #expect(result.contains("-project"))
        #expect(result.contains("Test.xcodeproj"))
    }

    @Test("formatCommand quotes arguments with spaces")
    func formatCommandWithSpaces() {
        let result = CommandHelpers.formatCommand("xcodebuild", arguments: ["-destination", "platform=iOS Simulator"])
        #expect(result.contains("'platform=iOS Simulator'"))
    }

    @Test("formatCommand quotes arguments with equals signs")
    func formatCommandWithEquals() {
        let result = CommandHelpers.formatCommand("xcodebuild", arguments: ["CODE_SIGN_IDENTITY="])
        #expect(result.contains("'CODE_SIGN_IDENTITY='"))
    }

    @Test("formatCommand quotes arguments with colons")
    func formatCommandWithColons() {
        let result = CommandHelpers.formatCommand("xcodebuild", arguments: ["-destination", "name:iPhone 16"])
        #expect(result.contains("'name:iPhone 16'"))
    }

    @Test("formatCommand does not quote simple arguments")
    func formatCommandSimpleArgs() {
        let result = CommandHelpers.formatCommand("xcodebuild", arguments: ["-scheme", "Fennec", "-sdk", "iphonesimulator"])
        // Simple arguments should not be quoted
        #expect(!result.contains("'Fennec'"))
        #expect(!result.contains("'-scheme'"))
        #expect(result.contains("Fennec"))
        #expect(result.contains("-scheme"))
    }

    @Test("formatCommand handles empty arguments list")
    func formatCommandEmptyArgs() {
        let result = CommandHelpers.formatCommand("xcodebuild", arguments: [])
        #expect(result == "xcodebuild ")
    }

    @Test("formatCommand uses line continuation")
    func formatCommandLineContinuation() {
        let args = ["-project", "Test.xcodeproj", "-scheme", "Fennec"]
        let result = CommandHelpers.formatCommand("xcodebuild", arguments: args)
        #expect(result.contains(" \\\n    "))
    }

    // MARK: - resolveProduct Tests

    @Test("resolveProduct returns explicit product when provided")
    func resolveProductExplicit() {
        let projectConfig = FxiosConfig(
            project: "firefox-ios", defaultBootstrap: nil, defaultBuildProduct: "firefox")
        let config = MergedConfig(projectConfig: projectConfig)
        let result = CommandHelpers.resolveProduct(explicit: .focus, config: config)
        #expect(result == .focus)
    }

    @Test("resolveProduct returns config default when no explicit")
    func resolveProductFromConfig() {
        let projectConfig = FxiosConfig(
            project: "firefox-ios", defaultBootstrap: nil, defaultBuildProduct: "focus")
        let config = MergedConfig(projectConfig: projectConfig)
        let result = CommandHelpers.resolveProduct(explicit: nil, config: config)
        #expect(result == .focus)
    }

    @Test("resolveProduct returns firefox as fallback default")
    func resolveProductDefault() {
        let projectConfig = FxiosConfig(
            project: "firefox-ios", defaultBootstrap: nil, defaultBuildProduct: nil)
        let config = MergedConfig(projectConfig: projectConfig)
        let result = CommandHelpers.resolveProduct(explicit: nil, config: config)
        #expect(result == .firefox)
    }

    @Test("resolveProduct handles invalid config value")
    func resolveProductInvalidConfig() {
        let projectConfig = FxiosConfig(
            project: "firefox-ios", defaultBootstrap: nil, defaultBuildProduct: "invalid")
        let config = MergedConfig(projectConfig: projectConfig)
        let result = CommandHelpers.resolveProduct(explicit: nil, config: config)
        #expect(result == .firefox) // Falls back to default
    }

    @Test("resolveProduct explicit overrides config")
    func resolveProductExplicitOverridesConfig() {
        let projectConfig = FxiosConfig(
            project: "firefox-ios", defaultBootstrap: nil, defaultBuildProduct: "focus")
        let config = MergedConfig(projectConfig: projectConfig)
        let result = CommandHelpers.resolveProduct(explicit: .klar, config: config)
        #expect(result == .klar)
    }

    // MARK: - buildXcodebuildArgs Tests

    @Test("buildXcodebuildArgs includes project path")
    func buildArgsIncludesProject() {
        let projectPath = URL(fileURLWithPath: "/path/to/Client.xcodeproj")
        let simulator = createMockSimulatorSelection()

        let args = CommandHelpers.buildXcodebuildArgs(
            projectPath: projectPath,
            scheme: "Fennec",
            configuration: "Fennec",
            simulator: simulator,
            derivedDataPath: nil
        )

        #expect(args.contains("-project"))
        #expect(args.contains("/path/to/Client.xcodeproj"))
    }

    @Test("buildXcodebuildArgs includes scheme")
    func buildArgsIncludesScheme() {
        let projectPath = URL(fileURLWithPath: "/path/to/Client.xcodeproj")
        let simulator = createMockSimulatorSelection()

        let args = CommandHelpers.buildXcodebuildArgs(
            projectPath: projectPath,
            scheme: "Fennec",
            configuration: "Fennec",
            simulator: simulator,
            derivedDataPath: nil
        )

        #expect(args.contains("-scheme"))
        #expect(args.contains("Fennec"))
    }

    @Test("buildXcodebuildArgs includes configuration")
    func buildArgsIncludesConfiguration() {
        let projectPath = URL(fileURLWithPath: "/path/to/Client.xcodeproj")
        let simulator = createMockSimulatorSelection()

        let args = CommandHelpers.buildXcodebuildArgs(
            projectPath: projectPath,
            scheme: "Fennec",
            configuration: "Fennec_Testing",
            simulator: simulator,
            derivedDataPath: nil
        )

        #expect(args.contains("-configuration"))
        #expect(args.contains("Fennec_Testing"))
    }

    @Test("buildXcodebuildArgs includes simulator destination")
    func buildArgsIncludesDestination() {
        let projectPath = URL(fileURLWithPath: "/path/to/Client.xcodeproj")
        let simulator = createMockSimulatorSelection()

        let args = CommandHelpers.buildXcodebuildArgs(
            projectPath: projectPath,
            scheme: "Fennec",
            configuration: "Fennec",
            simulator: simulator,
            derivedDataPath: nil
        )

        #expect(args.contains("-destination"))
        let destIndex = args.firstIndex(of: "-destination")!
        let destValue = args[args.index(after: destIndex)]
        #expect(destValue.contains("platform=iOS Simulator"))
        #expect(destValue.contains("name=iPhone 16"))
        #expect(destValue.contains("OS=18.2"))
    }

    @Test("buildXcodebuildArgs uses iphonesimulator SDK")
    func buildArgsUsesSimulatorSDK() {
        let projectPath = URL(fileURLWithPath: "/path/to/Client.xcodeproj")
        let simulator = createMockSimulatorSelection()

        let args = CommandHelpers.buildXcodebuildArgs(
            projectPath: projectPath,
            scheme: "Fennec",
            configuration: "Fennec",
            simulator: simulator,
            derivedDataPath: nil
        )

        #expect(args.contains("-sdk"))
        #expect(args.contains("iphonesimulator"))
    }

    @Test("buildXcodebuildArgs includes derived data path when specified")
    func buildArgsIncludesDerivedData() {
        let projectPath = URL(fileURLWithPath: "/path/to/Client.xcodeproj")
        let simulator = createMockSimulatorSelection()

        let args = CommandHelpers.buildXcodebuildArgs(
            projectPath: projectPath,
            scheme: "Fennec",
            configuration: "Fennec",
            simulator: simulator,
            derivedDataPath: "/tmp/DerivedData"
        )

        #expect(args.contains("-derivedDataPath"))
        #expect(args.contains("/tmp/DerivedData"))
    }

    @Test("buildXcodebuildArgs omits derived data path when nil")
    func buildArgsOmitsDerivedDataWhenNil() {
        let projectPath = URL(fileURLWithPath: "/path/to/Client.xcodeproj")
        let simulator = createMockSimulatorSelection()

        let args = CommandHelpers.buildXcodebuildArgs(
            projectPath: projectPath,
            scheme: "Fennec",
            configuration: "Fennec",
            simulator: simulator,
            derivedDataPath: nil
        )

        #expect(!args.contains("-derivedDataPath"))
    }

    @Test("buildXcodebuildArgs disables code signing for simulator")
    func buildArgsDisablesCodeSigning() {
        let projectPath = URL(fileURLWithPath: "/path/to/Client.xcodeproj")
        let simulator = createMockSimulatorSelection()

        let args = CommandHelpers.buildXcodebuildArgs(
            projectPath: projectPath,
            scheme: "Fennec",
            configuration: "Fennec",
            simulator: simulator,
            derivedDataPath: nil
        )

        #expect(args.contains("CODE_SIGN_IDENTITY="))
        #expect(args.contains("CODE_SIGNING_REQUIRED=NO"))
        #expect(args.contains("CODE_SIGNING_ALLOWED=NO"))
    }

    @Test("buildXcodebuildArgs disables index store")
    func buildArgsDisablesIndexStore() {
        let projectPath = URL(fileURLWithPath: "/path/to/Client.xcodeproj")
        let simulator = createMockSimulatorSelection()

        let args = CommandHelpers.buildXcodebuildArgs(
            projectPath: projectPath,
            scheme: "Fennec",
            configuration: "Fennec",
            simulator: simulator,
            derivedDataPath: nil
        )

        #expect(args.contains("COMPILER_INDEX_STORE_ENABLE=NO"))
    }

    @Test("buildXcodebuildArgs skips macro validation by default")
    func buildArgsSkipMacroValidationByDefault() {
        let projectPath = URL(fileURLWithPath: "/path/to/Client.xcodeproj")
        let simulator = createMockSimulatorSelection()

        let args = CommandHelpers.buildXcodebuildArgs(
            projectPath: projectPath,
            scheme: "Fennec",
            configuration: "Fennec",
            simulator: simulator,
            derivedDataPath: nil
        )

        #expect(args.contains("-skipMacroValidation"))
    }

    @Test("buildXcodebuildArgs can omit macro validation skip")
    func buildArgsCanOmitMacroValidationSkip() {
        let projectPath = URL(fileURLWithPath: "/path/to/Client.xcodeproj")
        let simulator = createMockSimulatorSelection()

        let args = CommandHelpers.buildXcodebuildArgs(
            projectPath: projectPath,
            scheme: "Fennec",
            configuration: "Fennec",
            simulator: simulator,
            derivedDataPath: nil,
            skipMacroValidation: false
        )

        #expect(!args.contains("-skipMacroValidation"))
    }

    // MARK: - buildXcodebuildArgsForDevice Tests

    @Test("buildXcodebuildArgsForDevice includes project path")
    func buildDeviceArgsIncludesProject() {
        let projectPath = URL(fileURLWithPath: "/path/to/Client.xcodeproj")

        let args = CommandHelpers.buildXcodebuildArgsForDevice(
            projectPath: projectPath,
            scheme: "Fennec",
            configuration: "Fennec",
            derivedDataPath: nil
        )

        #expect(args.contains("-project"))
        #expect(args.contains("/path/to/Client.xcodeproj"))
    }

    @Test("buildXcodebuildArgsForDevice uses generic iOS destination")
    func buildDeviceArgsUsesGenericDestination() {
        let projectPath = URL(fileURLWithPath: "/path/to/Client.xcodeproj")

        let args = CommandHelpers.buildXcodebuildArgsForDevice(
            projectPath: projectPath,
            scheme: "Fennec",
            configuration: "Fennec",
            derivedDataPath: nil
        )

        #expect(args.contains("-destination"))
        #expect(args.contains("generic/platform=iOS"))
    }

    @Test("buildXcodebuildArgsForDevice uses iphoneos SDK")
    func buildDeviceArgsUsesDeviceSDK() {
        let projectPath = URL(fileURLWithPath: "/path/to/Client.xcodeproj")

        let args = CommandHelpers.buildXcodebuildArgsForDevice(
            projectPath: projectPath,
            scheme: "Fennec",
            configuration: "Fennec",
            derivedDataPath: nil
        )

        #expect(args.contains("-sdk"))
        #expect(args.contains("iphoneos"))
    }

    @Test("buildXcodebuildArgsForDevice does not disable code signing")
    func buildDeviceArgsAllowsCodeSigning() {
        let projectPath = URL(fileURLWithPath: "/path/to/Client.xcodeproj")

        let args = CommandHelpers.buildXcodebuildArgsForDevice(
            projectPath: projectPath,
            scheme: "Fennec",
            configuration: "Fennec",
            derivedDataPath: nil
        )

        // Device builds should NOT disable code signing
        #expect(!args.contains("CODE_SIGN_IDENTITY="))
        #expect(!args.contains("CODE_SIGNING_REQUIRED=NO"))
        #expect(!args.contains("CODE_SIGNING_ALLOWED=NO"))
    }

    @Test("buildXcodebuildArgsForDevice disables index store")
    func buildDeviceArgsDisablesIndexStore() {
        let projectPath = URL(fileURLWithPath: "/path/to/Client.xcodeproj")

        let args = CommandHelpers.buildXcodebuildArgsForDevice(
            projectPath: projectPath,
            scheme: "Fennec",
            configuration: "Fennec",
            derivedDataPath: nil
        )

        #expect(args.contains("COMPILER_INDEX_STORE_ENABLE=NO"))
    }

    @Test("buildXcodebuildArgsForDevice includes derived data path when specified")
    func buildDeviceArgsIncludesDerivedData() {
        let projectPath = URL(fileURLWithPath: "/path/to/Client.xcodeproj")

        let args = CommandHelpers.buildXcodebuildArgsForDevice(
            projectPath: projectPath,
            scheme: "Fennec",
            configuration: "Fennec",
            derivedDataPath: "/tmp/DerivedData"
        )

        #expect(args.contains("-derivedDataPath"))
        #expect(args.contains("/tmp/DerivedData"))
    }

    @Test("buildXcodebuildArgsForDevice skips macro validation by default")
    func buildDeviceArgsSkipMacroValidationByDefault() {
        let projectPath = URL(fileURLWithPath: "/path/to/Client.xcodeproj")

        let args = CommandHelpers.buildXcodebuildArgsForDevice(
            projectPath: projectPath,
            scheme: "Fennec",
            configuration: "Fennec",
            derivedDataPath: nil
        )

        #expect(args.contains("-skipMacroValidation"))
    }

    @Test("buildXcodebuildArgsForDevice can omit macro validation skip")
    func buildDeviceArgsCanOmitMacroValidationSkip() {
        let projectPath = URL(fileURLWithPath: "/path/to/Client.xcodeproj")

        let args = CommandHelpers.buildXcodebuildArgsForDevice(
            projectPath: projectPath,
            scheme: "Fennec",
            configuration: "Fennec",
            derivedDataPath: nil,
            skipMacroValidation: false
        )

        #expect(!args.contains("-skipMacroValidation"))
    }

    // MARK: - ListSims Command Tests

    @Test("ListSims command has correct configuration")
    func listSimsConfiguration() {
        #expect(ListSims.configuration.commandName == "list-sims")
        #expect(!ListSims.configuration.abstract.isEmpty)
    }

    // MARK: - Helper Methods

    private func createMockSimulatorSelection() -> SimulatorSelection {
        let simulator = Simulator(
            udid: "test-udid-12345",
            name: "iPhone 16",
            state: "Shutdown",
            isAvailable: true
        )
        let runtime = SimulatorRuntime(
            identifier: "com.apple.CoreSimulator.SimRuntime.iOS-18-2",
            name: "iOS 18.2",
            version: "18.2",
            isAvailable: true
        )
        return SimulatorSelection(simulator: simulator, runtime: runtime)
    }
}
