// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import ArgumentParser
import Foundation

// MARK: - Run Errors

enum RunError: Error, CustomStringConvertible {
    case appNotFound(String)
    case simulatorOnly

    var description: String {
        switch self {
        case .appNotFound(let path):
            return "Built app not found at expected path: \(path). Build may have failed."
        case .simulatorOnly:
            return "The 'run' command only supports simulators. Use 'build --device' for device builds."
        }
    }
}

// MARK: - Run Command

struct Run: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "run",
        abstract: "Build and launch Firefox, Focus, or Klar in the simulator.",
        discussion: """
            Builds the specified product and launches it in the iOS Simulator. \
            This is equivalent to running 'fxios build' followed by launching \
            the app.

            Use 'fxios run list-sims' to see available simulators and their shorthand codes.
            The latest iOS version is used unless --os is specified.
            """,
        subcommands: [ListSims.self],
        defaultSubcommand: nil
    )

    // swiftlint:disable line_length
    // MARK: - Product Selection

    @Option(name: [.short, .long], help: "Product to build and run: firefox, focus, or klar.")
    var product: BuildProduct?

    // MARK: - Destination

    @Option(name: .long, help: "Simulator shorthand or name (e.g., 17pro, mini, \"iPhone 17 Pro\"). Use 'list-sims' subcommand to see shorthands.")
    var sim: String?

    @Option(name: .long, help: "iOS version for simulator (default: latest).")
    var os: String?

    // MARK: - Configuration

    @Option(name: .long, help: "Override the build configuration.")
    var configuration: String?

    @Option(name: .long, help: "Custom derived data path.")
    var derivedData: String?

    @Flag(
        name: [.customLong("doNotSkipMacroValidation"), .customLong("do-not-skip-macro-validation")],
        help: "Do not pass -skipMacroValidation to xcodebuild."
    )
    var doNotSkipMacroValidation = false

    var skipMacroValidation: Bool { !doNotSkipMacroValidation }

    // MARK: - Workflow Options

    @Flag(name: .long, help: "Skip resolving Swift Package dependencies.")
    var skipResolve = false

    @Flag(name: .long, help: "Clean build folder before building.")
    var clean = false

    @Flag(name: [.short, .long], help: "Minimize output (show only errors and summary).")
    var quiet = false

    @Flag(name: .long, help: "Print the commands instead of running them.")
    var expose = false

    // swiftlint:enable line_length

    // MARK: - Run

    mutating func run() throws {
        // Validate we're in a firefox-ios repository
        let repo = try RepoDetector.requireValidRepo()

        // Check for required tools
        try ToolChecker.requireXcodebuild()
        try ToolChecker.requireSimctl()

        // Determine product
        let buildProduct = CommandHelpers.resolveProduct(explicit: product, config: repo.config)

        // Validate project exists
        let projectPath = repo.root.appendingPathComponent(buildProduct.projectPath)
        guard FileManager.default.fileExists(atPath: projectPath.path) else {
            throw BuildError.projectNotFound(projectPath.path)
        }

        // Determine simulator
        let simulatorSelection = try CommandHelpers.resolveSimulator(shorthand: sim, osVersion: os)

        // Handle --expose: print commands instead of running
        if expose {
            printExposedCommands(
                product: buildProduct,
                projectPath: projectPath,
                simulator: simulatorSelection
            )
            return
        }

        // Print run info
        if !quiet {
            Herald.declare("Run Configuration:", isNewCommand: true)
            Herald.declare("  Product: \(buildProduct.scheme)")
            Herald.declare("  Simulator: \(simulatorSelection.simulator.name) (iOS \(simulatorSelection.runtime.version))")
            Herald.declare("")
        }

        // Clean if requested
        if clean {
            try CommandHelpers.cleanDerivedData(path: derivedData, quiet: quiet)
        }

        // Resolve packages
        if !skipResolve {
            try CommandHelpers.resolvePackages(projectPath: projectPath, quiet: quiet)
        }

        // Build
        try performBuild(
            product: buildProduct,
            projectPath: projectPath,
            simulator: simulatorSelection,
            repoRoot: repo.root
        )

        // Boot simulator if needed
        if !quiet {
            Herald.declare("Booting simulator...")
        }
        try SimulatorManager.bootSimulator(udid: simulatorSelection.simulator.udid)

        // Open Simulator.app
        try SimulatorManager.openSimulatorApp()

        // Find the built app
        let appPath = try findBuiltApp(product: buildProduct, repoRoot: repo.root)

        // Install the app
        if !quiet {
            Herald.declare("Installing \(buildProduct.scheme)...")
        }
        try SimulatorManager.installApp(path: appPath, simulatorUdid: simulatorSelection.simulator.udid)

        // Launch the app
        if !quiet {
            Herald.declare("Launching \(buildProduct.scheme)...")
        }
        try SimulatorManager.launchApp(
            bundleId: buildProduct.bundleIdentifier,
            simulatorUdid: simulatorSelection.simulator.udid
        )

        Herald.declare("\(buildProduct.scheme) is running in \(simulatorSelection.simulator.name)!", isNewCommand: quiet, asConclusion: true)
    }

    // MARK: - Private Methods

    private func performBuild(
        product: BuildProduct,
        projectPath: URL,
        simulator: SimulatorSelection,
        repoRoot: URL
    ) throws {
        if !quiet {
            Herald.declare("Building \(product.scheme)...")
        }

        let config = configuration ?? product.defaultConfiguration
        var args = CommandHelpers.buildXcodebuildArgs(
            projectPath: projectPath,
            scheme: product.scheme,
            configuration: config,
            simulator: simulator,
            derivedDataPath: derivedData,
            skipMacroValidation: skipMacroValidation
        )

        // Add build action
        args.append("build")

        try CommandHelpers.runXcodebuild(arguments: args, quiet: quiet) { exitCode in
            BuildError.buildFailed(exitCode: exitCode)
        }

        if !quiet {
            Herald.declare("Build succeeded!")
            Herald.declare("")
        }
    }

    private func findBuiltApp(product: BuildProduct, repoRoot: URL) throws -> String {
        // The app is built to DerivedData
        // swiftlint:disable:next line_length
        // Default location: ~/Library/Developer/Xcode/DerivedData/{ProjectName}-{hash}/Build/Products/{Configuration}-iphonesimulator/{AppName}.app

        let config = configuration ?? product.defaultConfiguration
        let fileManager = FileManager.default

        // If custom derived data path was specified
        if let derivedDataPath = derivedData {
            let appPath = "\(derivedDataPath)/Build/Products/\(config)-iphonesimulator/\(product.scheme).app"
            if fileManager.fileExists(atPath: appPath) {
                return appPath
            }
        }

        // Search in default DerivedData location
        let derivedDataBase = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Developer/Xcode/DerivedData")

        // Find the project's derived data folder
        let projectName: String
        switch product {
        case .firefox:
            projectName = "Client"
        case .focus, .klar:
            projectName = "Blockzilla"
        }

        guard let contents = try? fileManager.contentsOfDirectory(atPath: derivedDataBase.path) else {
            throw RunError.appNotFound("Could not read DerivedData directory")
        }

        // Find matching folder (e.g., "Client-abcdef123")
        guard let matchingFolder = contents.first(where: { $0.hasPrefix(projectName + "-") }) else {
            throw RunError.appNotFound("No DerivedData folder found for \(projectName)")
        }

        let appPath = derivedDataBase
            .appendingPathComponent(matchingFolder)
            .appendingPathComponent("Build/Products/\(config)-iphonesimulator/\(product.scheme).app")

        guard fileManager.fileExists(atPath: appPath.path) else {
            throw RunError.appNotFound(appPath.path)
        }

        return appPath.path
    }

    // MARK: - Expose Command

    private func printExposedCommands(
        product: BuildProduct,
        projectPath: URL,
        simulator: SimulatorSelection
    ) {
        // Print resolve command if applicable
        if !skipResolve {
            let resolveArgs = [
                "-resolvePackageDependencies",
                "-onlyUsePackageVersionsFromResolvedFile",
                "-project", projectPath.path
            ]
            Herald.raw("# Resolve Swift Package dependencies")
            Herald.raw(CommandHelpers.formatCommand("xcodebuild", arguments: resolveArgs))
            Herald.raw("")
        }

        // Print build command
        let config = configuration ?? product.defaultConfiguration
        var buildArgs = CommandHelpers.buildXcodebuildArgs(
            projectPath: projectPath,
            scheme: product.scheme,
            configuration: config,
            simulator: simulator,
            derivedDataPath: derivedData,
            skipMacroValidation: skipMacroValidation
        )
        buildArgs.append("build")

        Herald.raw("# Build \(product.scheme)")
        Herald.raw(CommandHelpers.formatCommand("xcodebuild", arguments: buildArgs))
        Herald.raw("")

        // Print simctl commands
        Herald.raw("# Boot simulator")
        Herald.raw("xcrun simctl boot '\(simulator.simulator.udid)'")
        Herald.raw("")

        Herald.raw("# Open Simulator.app")
        Herald.raw("open -a Simulator")
        Herald.raw("")

        // Note: We can't know the exact app path without building
        let appPathExample = "~/Library/Developer/Xcode/DerivedData/.../Build/Products/\(config)-iphonesimulator/\(product.scheme).app"

        Herald.raw("# Install app (path determined after build)")
        Herald.raw("xcrun simctl install '\(simulator.simulator.udid)' '\(appPathExample)'")
        Herald.raw("")

        Herald.raw("# Launch app")
        Herald.raw("xcrun simctl launch '\(simulator.simulator.udid)' '\(product.bundleIdentifier)'")
    }
}
