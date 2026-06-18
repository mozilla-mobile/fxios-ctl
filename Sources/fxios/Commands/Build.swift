// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import ArgumentParser
import Foundation

// MARK: - Build Errors

enum BuildError: Error, CustomStringConvertible {
    case projectNotFound(String)
    case buildFailed(exitCode: Int32)

    var description: String {
        switch self {
        case .projectNotFound(let path):
            return "Project not found at \(path). Run 'fxios setup' first."
        case .buildFailed(let exitCode):
            return "Build failed with exit code \(exitCode)."
        }
    }
}

// MARK: - Build Command

struct Build: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "build",
        abstract: "Build Firefox, Focus, or Klar for development.",
        discussion: """
            Builds the specified product using xcodebuild. By default, builds \
            Firefox for the iOS Simulator in debug configuration.

            Use 'fxios build list-sims' to see available simulators and their shorthand codes.
            The latest iOS version is used unless --os is specified.
            """,
        subcommands: [ListSims.self],
        defaultSubcommand: nil
    )

    // swiftlint:disable line_length
    // MARK: - Product Selection

    @Option(name: [.short, .long], help: "Product to build")
    var product: BuildProduct?

    // MARK: - Build Type

    @Flag(name: .long, help: "Build for testing (generates xctestrun bundle).")
    var forTesting = false

    // MARK: - Destination

    @Flag(name: [.short, .long], help: "Build for a connected device instead of simulator.")
    var device = false

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

    // MARK: - Info

    @Flag(name: .long, help: "Print the xcodebuild command instead of running it.")
    var expose = false

    // swiftlint:enable line_length

    // MARK: - Run

    mutating func run() throws {
        // Validate we're in a firefox-ios repository
        let repo = try RepoDetector.requireValidRepo()

        // Check for required tools
        try ToolChecker.requireXcodebuild()

        // Determine product
        let buildProduct = CommandHelpers.resolveProduct(explicit: product, config: repo.config)

        // Validate project exists
        let projectPath = repo.root.appendingPathComponent(buildProduct.projectPath)
        guard FileManager.default.fileExists(atPath: projectPath.path) else {
            throw BuildError.projectNotFound(projectPath.path)
        }

        // Determine simulator (if not building for device)
        var simulatorSelection: SimulatorSelection?
        if !device {
            try ToolChecker.requireSimctl()
            simulatorSelection = try CommandHelpers.resolveSimulator(shorthand: sim, osVersion: os)
        }

        // Handle --expose: print commands instead of running
        if expose {
            printExposedCommands(
                product: buildProduct,
                projectPath: projectPath,
                simulator: simulatorSelection
            )
            return
        }

        // Print build info
        printBuildInfo(product: buildProduct, simulator: simulatorSelection, repoRoot: repo.root)

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
            simulator: simulatorSelection
        )

        Herald.declare("Build succeeded!", isNewCommand: quiet, asConclusion: true)
    }

    // MARK: - Private Methods

    private func printBuildInfo(product: BuildProduct, simulator: SimulatorSelection?, repoRoot: URL) {
        if quiet { return }

        Herald.declare("Build Configuration:", isNewCommand: true)
        Herald.declare("  Product: \(product.scheme)")
        Herald.declare("  Project: \(product.projectPath)")

        let config = configuration ?? (forTesting ? product.testingConfiguration : product.defaultConfiguration)
        Herald.declare("  Configuration: \(config)")

        if let sim = simulator {
            Herald.declare("  Simulator: \(sim.simulator.name) (iOS \(sim.runtime.version))")
        } else if device {
            Herald.declare("  Destination: Connected device")
        }

        if forTesting {
            Herald.declare("  Build Type: build-for-testing")
        }

        Herald.declare("")
    }

    private func performBuild(
        product: BuildProduct,
        projectPath: URL,
        simulator: SimulatorSelection?
    ) throws {
        if !quiet {
            Herald.declare("Building \(product.scheme)...")
        }

        var args = buildXcodebuildArgs(
            product: product,
            projectPath: projectPath,
            simulator: simulator
        )

        // Add build action
        args.append(forTesting ? "build-for-testing" : "build")

        try CommandHelpers.runXcodebuild(arguments: args, quiet: quiet) { exitCode in
            BuildError.buildFailed(exitCode: exitCode)
        }
    }

    private func buildXcodebuildArgs(
        product: BuildProduct,
        projectPath: URL,
        simulator: SimulatorSelection?
    ) -> [String] {
        let config = configuration ?? (forTesting ? product.testingConfiguration : product.defaultConfiguration)

        if device {
            return CommandHelpers.buildXcodebuildArgsForDevice(
                projectPath: projectPath,
                scheme: product.scheme,
                configuration: config,
                derivedDataPath: derivedData,
                skipMacroValidation: skipMacroValidation
            )
        } else if let sim = simulator {
            return CommandHelpers.buildXcodebuildArgs(
                projectPath: projectPath,
                scheme: product.scheme,
                configuration: config,
                simulator: sim,
                derivedDataPath: derivedData,
                skipMacroValidation: skipMacroValidation
            )
        }

        return []
    }

    // MARK: - Expose Command

    private func printExposedCommands(
        product: BuildProduct,
        projectPath: URL,
        simulator: SimulatorSelection?
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
        var buildArgs = buildXcodebuildArgs(
            product: product,
            projectPath: projectPath,
            simulator: simulator
        )
        buildArgs.append(forTesting ? "build-for-testing" : "build")

        Herald.raw("# Build \(product.scheme)")
        Herald.raw(CommandHelpers.formatCommand("xcodebuild", arguments: buildArgs))
    }
}
