// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import ArgumentParser
import Foundation

// MARK: - Shared ListSims Subcommand

/// Shared subcommand for listing available simulators
/// Used by Build, Run, and Test commands
struct ListSims: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list-sims",
        abstract: "List available simulators and their shorthand codes."
    )

    func run() throws {
        try CommandHelpers.printSimulatorList()
    }
}

// MARK: - Command Helpers

/// Shared utilities for command implementations
enum CommandHelpers {
    // MARK: - Command Formatting

    /// Formats a command and its arguments for display (used by --expose)
    /// Arguments containing spaces, equals signs, or colons are quoted
    static func formatCommand(_ command: String, arguments: [String]) -> String {
        let escapedArgs = arguments.map { arg -> String in
            if arg.contains(" ") || arg.contains("=") || arg.contains(":") {
                return "'\(arg)'"
            }
            return arg
        }
        return "\(command) \(escapedArgs.joined(separator: " \\\n    "))"
    }

    // MARK: - Simulator Utilities

    /// Prints a formatted table of available iOS simulators with their shorthand codes
    static func printSimulatorList() throws {
        try ToolChecker.requireSimctl()

        let simulatorsByRuntime = try SimulatorManager.listSimulators()

        guard !simulatorsByRuntime.isEmpty else {
            Herald.declare("No iOS simulators found. Please install simulators via Xcode.", isNewCommand: true)
            return
        }

        // Gather unique devices with their available iOS versions
        // swiftlint:disable:next large_tuple
        var deviceInfo: [String: (shorthand: String?, versions: [String], isBooted: Bool)] = [:]

        for (runtime, devices) in simulatorsByRuntime {
            for device in devices {
                if var info = deviceInfo[device.name] {
                    if !info.versions.contains(runtime.version) {
                        info.versions.append(runtime.version)
                    }
                    if device.isBooted {
                        info.isBooted = true
                    }
                    deviceInfo[device.name] = info
                } else {
                    let shorthand = DeviceShorthand.shorthand(for: device.name)
                    deviceInfo[device.name] = (shorthand: shorthand, versions: [runtime.version], isBooted: device.isBooted)
                }
            }
        }

        // Sort devices: iPhones first, then iPads, alphabetically within each group
        let sortedDevices = deviceInfo.keys.sorted { name1, name2 in
            let isPhone1 = name1.hasPrefix("iPhone")
            let isPhone2 = name2.hasPrefix("iPhone")
            if isPhone1 != isPhone2 {
                return isPhone1 // iPhones come first
            }
            return name1 < name2
        }

        // Calculate column widths
        let deviceHeader = "Device Name"
        let shorthandHeader = "Shorthand"
        let versionsHeader = "iOS Versions"

        var maxDeviceWidth = deviceHeader.count
        var maxShorthandWidth = shorthandHeader.count

        for name in sortedDevices {
            maxDeviceWidth = max(maxDeviceWidth, name.count + (deviceInfo[name]?.isBooted == true ? 9 : 0)) // " (Booted)"
            if let shorthand = deviceInfo[name]?.shorthand {
                maxShorthandWidth = max(maxShorthandWidth, shorthand.count)
            }
        }

        // Add padding
        maxDeviceWidth += 2
        maxShorthandWidth += 2

        // Print header
        Herald.declare("Available Simulators:", isNewCommand: true)
        Herald.declare("")

        let headerLine = deviceHeader.padding(toLength: maxDeviceWidth, withPad: " ", startingAt: 0) +
                        shorthandHeader.padding(toLength: maxShorthandWidth, withPad: " ", startingAt: 0) +
                        versionsHeader
        Herald.declare(headerLine)
        Herald.declare(String(repeating: "-", count: headerLine.count + 10))

        // Print devices
        for name in sortedDevices {
            guard let info = deviceInfo[name] else { continue }

            let bootedSuffix = info.isBooted ? " (Booted)" : ""
            let deviceCol = (name + bootedSuffix).padding(toLength: maxDeviceWidth, withPad: " ", startingAt: 0)
            let shorthandCol = (info.shorthand ?? "-").padding(toLength: maxShorthandWidth, withPad: " ", startingAt: 0)
            let versionsCol = info.versions.joined(separator: ", ")

            Herald.declare(deviceCol + shorthandCol + versionsCol)
        }

        Herald.declare("")

        // Show default (reuse the already-fetched simulator list)
        do {
            let defaultSim = try SimulatorManager.findDefaultSimulator(from: simulatorsByRuntime)
            Herald.declare("Default: \(defaultSim.simulator.name) (iOS \(defaultSim.runtime.version))")
        } catch {
            Logger.debug("Could not determine default simulator: \(error)")
            Herald.declare("Could not determine default simulator: \(error)", asError: true)
        }

        Herald.declare("")
        Herald.declare("Usage: --sim <shorthand or name>  (e.g., --sim 17pro, --sim \"iPhone 17 Pro\")")
        Herald.declare("Note: Devices marked \"-\" require the full name (e.g., --sim \"Device Name\")")
    }

    /// Resolves simulator from shorthand, exact name, or returns default
    static func resolveSimulator(shorthand: String?, osVersion: String?) throws -> SimulatorSelection {
        if let shorthand = shorthand {
            // Try shorthand first
            do {
                return try DeviceShorthand.findSimulator(
                    shorthand: shorthand,
                    osVersion: osVersion
                )
            } catch let error as DeviceShorthandError {
                // If it's an invalid shorthand, try as an exact name
                if case .invalidShorthand = error {
                    return try SimulatorManager.findSimulator(name: shorthand, osVersion: osVersion)
                }
                throw error
            }
        } else {
            return try SimulatorManager.findDefaultSimulator()
        }
    }

    // MARK: - Product Resolution

    /// Resolves product from explicit value or config (which includes defaults)
    static func resolveProduct(explicit: BuildProduct?, config: MergedConfig) -> BuildProduct {
        // Priority: command line flag > merged config (which already has defaults applied)
        if let explicit = explicit {
            return explicit
        }

        return BuildProduct(rawValue: config.defaultBuildProduct) ?? .firefox
    }

    // MARK: - Package Resolution

    /// Resolves Swift Package dependencies
    static func resolvePackages(projectPath: URL, quiet: Bool) throws {
        if !quiet {
            Herald.declare("Resolving Swift Package dependencies...")
        }

        let args = [
            "-resolvePackageDependencies",
            "-onlyUsePackageVersionsFromResolvedFile",
            "-project", projectPath.path
        ]

        if quiet {
            _ = try ShellRunner.runAndCapture("xcodebuild", arguments: args)
        } else {
            try ShellRunner.run("xcodebuild", arguments: args)
        }

        if !quiet {
            Herald.declare("Package resolution complete.")
            Herald.declare("")
        }
    }

    // MARK: - Clean Utilities

    /// Cleans derived data directory if specified
    static func cleanDerivedData(path: String?, quiet: Bool) throws {
        guard let derivedDataPath = path else { return }

        if !quiet {
            Herald.declare("Cleaning build folder...")
        }

        let ddURL = URL(fileURLWithPath: derivedDataPath)
        if FileManager.default.fileExists(atPath: ddURL.path) {
            try FileManager.default.removeItem(at: ddURL)
        }

        if !quiet {
            Herald.declare("Clean complete.")
        }
    }

    // MARK: - Xcodebuild Execution

    /// Runs xcodebuild with proper error handling for quiet/verbose modes
    static func runXcodebuild(
        arguments: [String],
        quiet: Bool,
        errorTransform: (Int32) -> Error
    ) throws {
        if quiet {
            do {
                _ = try ShellRunner.runAndCapture("xcodebuild", arguments: arguments)
            } catch let error as ShellRunnerError {
                if case .commandFailed(_, let exitCode) = error {
                    throw errorTransform(exitCode)
                }
                throw error
            }
        } else {
            do {
                try ShellRunner.run("xcodebuild", arguments: arguments)
            } catch let error as ShellRunnerError {
                if case .commandFailed(_, let exitCode) = error {
                    throw errorTransform(exitCode)
                }
                throw error
            }
        }
    }

    // MARK: - Xcodebuild Argument Building

    /// Builds xcodebuild arguments for simulator builds
    static func buildXcodebuildArgs(
        projectPath: URL,
        scheme: String,
        configuration: String,
        simulator: SimulatorSelection,
        derivedDataPath: String?,
        skipMacroValidation: Bool = true
    ) -> [String] {
        var args: [String] = []

        // Project and scheme
        args += ["-project", projectPath.path]
        args += ["-scheme", scheme]
        args += ["-configuration", configuration]

        // Destination and SDK for simulator
        let destination = "platform=iOS Simulator,name=\(simulator.simulator.name),OS=\(simulator.runtime.version)"
        args += ["-destination", destination]
        args += ["-sdk", "iphonesimulator"]

        // Derived data path
        if let derivedData = derivedDataPath {
            args += ["-derivedDataPath", derivedData]
        }

        if skipMacroValidation {
            args += ["-skipMacroValidation"]
        }

        // Common build settings
        args += ["COMPILER_INDEX_STORE_ENABLE=NO"]

        // Code signing for simulator builds
        args += ["CODE_SIGN_IDENTITY="]
        args += ["CODE_SIGNING_REQUIRED=NO"]
        args += ["CODE_SIGNING_ALLOWED=NO"]

        return args
    }

    /// Builds xcodebuild arguments for device builds
    static func buildXcodebuildArgsForDevice(
        projectPath: URL,
        scheme: String,
        configuration: String,
        derivedDataPath: String?,
        skipMacroValidation: Bool = true
    ) -> [String] {
        var args: [String] = []

        // Project and scheme
        args += ["-project", projectPath.path]
        args += ["-scheme", scheme]
        args += ["-configuration", configuration]

        // Destination and SDK for device
        args += ["-destination", "generic/platform=iOS"]
        args += ["-sdk", "iphoneos"]

        // Derived data path
        if let derivedData = derivedDataPath {
            args += ["-derivedDataPath", derivedData]
        }

        if skipMacroValidation {
            args += ["-skipMacroValidation"]
        }

        // Common build settings
        args += ["COMPILER_INDEX_STORE_ENABLE=NO"]

        return args
    }
}
