// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import ArgumentParser
import Foundation

// MARK: - Test Command

struct Test: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "test",
        abstract: "Run tests for Firefox, Focus, or Klar.",
        discussion: """
            Runs tests using xcodebuild. By default, runs unit tests for the \
            product specified in .fxios.yaml, or Firefox if not configured.

            TEST PLAN OPTIONS:
              - unit: Unit tests (default)
              - smoke: Smoke/UI tests
              - accessibility (a11y): Accessibility tests (Firefox only)
              - performance (perf): Performance tests (Firefox only)
              - full: Full functional tests (Focus/Klar only)

            Use 'fxios test list-sims' to see available simulators and their shorthand codes.
            The latest iOS version is used unless --os is specified.
            """,
        subcommands: [ListSims.self],
        defaultSubcommand: nil
    )

    // swiftlint:disable line_length
    // MARK: - Product Selection

    @Option(name: [.short, .long], help: "Product to test: firefox, focus, or klar.")
    var product: BuildProduct?

    // MARK: - Test Plan

    @Option(name: .long, help: "Test plan to run: unit, smoke, a11y (accessibility), perf (performance), or full.")
    var plan: TestPlan = .unit

    // MARK: - Test Filtering

    @Option(name: .long, help: "Filter tests by name (passed to -only-testing).")
    var filter: String?

    // MARK: - Destination

    @Option(name: .long, help: "Simulator shorthand or name (e.g., 17pro, mini, \"iPhone 17 Pro\"). Use 'list-sims' subcommand to see shorthands.")
    var sim: String?

    @Option(name: .long, help: "iOS version for simulator (default: latest).")
    var os: String?

    // MARK: - Build Options

    @Flag(name: .long, help: "Build for testing before running tests.")
    var buildFirst = false

    @Option(name: .long, help: "Custom derived data path.")
    var derivedData: String?

    @Flag(
        name: [.customLong("doNotSkipMacroValidation"), .customLong("do-not-skip-macro-validation")],
        help: "Do not pass -skipMacroValidation to xcodebuild."
    )
    var doNotSkipMacroValidation = false

    var skipMacroValidation: Bool { !doNotSkipMacroValidation }

    // MARK: - Test Options

    @Option(name: .long, help: "Maximum test retries on failure (default: 0).")
    var retries = 0

    // MARK: - Workflow Options

    @Flag(name: [.short, .long], help: "Minimize output (show only errors and summary).")
    var quiet = false

    @Flag(name: .long, help: "Print the xcodebuild command instead of running it.")
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
        let testProduct = CommandHelpers.resolveProduct(explicit: product, config: repo.config)

        // Validate test plan is available for this product
        guard plan.testPlanName(for: testProduct) != nil else {
            throw TestError.testPlanNotAvailable(plan: plan, product: testProduct)
        }

        // Validate project exists
        let projectPath = repo.root.appendingPathComponent(testProduct.projectPath)
        guard FileManager.default.fileExists(atPath: projectPath.path) else {
            throw BuildError.projectNotFound(projectPath.path)
        }

        // Determine simulator
        let simulatorSelection = try CommandHelpers.resolveSimulator(shorthand: sim, osVersion: os)

        // Handle --expose: print commands instead of running
        if expose {
            printExposedCommands(
                product: testProduct,
                projectPath: projectPath,
                simulator: simulatorSelection
            )
            return
        }

        // Print test info
        if !quiet {
            Herald.declare("Test Configuration:", isNewCommand: true)
            Herald.declare("  Product: \(testProduct.scheme)")
            Herald.declare("  Test Plan: \(plan.displayName)")
            Herald.declare("  Simulator: \(simulatorSelection.simulator.name) (iOS \(simulatorSelection.runtime.version))")
            if let filter = filter {
                Herald.declare("  Filter: \(filter)")
            }
            Herald.declare("")
        }

        // Build for testing if requested
        if buildFirst {
            try performBuildForTesting(
                product: testProduct,
                projectPath: projectPath,
                simulator: simulatorSelection
            )
        }

        // Run tests
        try runTests(
            product: testProduct,
            projectPath: projectPath,
            simulator: simulatorSelection,
            repoRoot: repo.root
        )

        Herald.declare("Tests passed!", isNewCommand: quiet, asConclusion: true)
    }

    // MARK: - Private Methods

    private func performBuildForTesting(
        product: BuildProduct,
        projectPath: URL,
        simulator: SimulatorSelection
    ) throws {
        if !quiet {
            Herald.declare("Building \(product.scheme) for testing...")
        }

        var args = CommandHelpers.buildXcodebuildArgs(
            projectPath: projectPath,
            scheme: product.scheme,
            configuration: product.testingConfiguration,
            simulator: simulator,
            derivedDataPath: derivedData,
            skipMacroValidation: skipMacroValidation
        )
        args.append("build-for-testing")

        try CommandHelpers.runXcodebuild(arguments: args, quiet: quiet) { exitCode in
            BuildError.buildFailed(exitCode: exitCode)
        }

        if !quiet {
            Herald.declare("Build for testing succeeded!")
            Herald.declare("")
        }
    }

    private func runTests(
        product: BuildProduct,
        projectPath: URL,
        simulator: SimulatorSelection,
        repoRoot: URL
    ) throws {
        if !quiet {
            Herald.declare("Running \(plan.displayName) for \(product.scheme)...")
        }

        // Start with base args (without derivedDataPath since we handle it separately for tests)
        var args = CommandHelpers.buildXcodebuildArgs(
            projectPath: projectPath,
            scheme: product.scheme,
            configuration: product.testingConfiguration,
            simulator: simulator,
            derivedDataPath: derivedData,
            skipMacroValidation: skipMacroValidation
        )

        // Add test plan if available
        if let testPlanName = plan.testPlanName(for: product) {
            args += ["-testPlan", testPlanName]
        }

        // Add test filter
        if let filter = filter {
            args += ["-only-testing:\(filter)"]
        }

        // Add retry count
        if retries > 0 {
            args += ["-retry-tests-on-failure"]
            args += ["-test-iterations", String(retries + 1)]
        }

        // Add test action
        args.append("test")

        try CommandHelpers.runXcodebuild(arguments: args, quiet: quiet) { exitCode in
            TestError.testsFailed(exitCode: exitCode)
        }
    }

    // MARK: - Expose Command

    private func printExposedCommands(
        product: BuildProduct,
        projectPath: URL,
        simulator: SimulatorSelection
    ) {
        // Print build-for-testing command if applicable
        if buildFirst {
            var buildArgs = CommandHelpers.buildXcodebuildArgs(
                projectPath: projectPath,
                scheme: product.scheme,
                configuration: product.testingConfiguration,
                simulator: simulator,
                derivedDataPath: derivedData,
                skipMacroValidation: skipMacroValidation
            )
            buildArgs.append("build-for-testing")

            Herald.raw("# Build for testing")
            Herald.raw(CommandHelpers.formatCommand("xcodebuild", arguments: buildArgs))
            Herald.raw("")
        }

        // Print test command
        var testArgs = CommandHelpers.buildXcodebuildArgs(
            projectPath: projectPath,
            scheme: product.scheme,
            configuration: product.testingConfiguration,
            simulator: simulator,
            derivedDataPath: derivedData,
            skipMacroValidation: skipMacroValidation
        )

        // Add test plan if available
        if let testPlanName = plan.testPlanName(for: product) {
            testArgs += ["-testPlan", testPlanName]
        }

        // Add test filter
        if let filter = filter {
            testArgs += ["-only-testing:\(filter)"]
        }

        // Add retry count
        if retries > 0 {
            testArgs += ["-retry-tests-on-failure"]
            testArgs += ["-test-iterations", String(retries + 1)]
        }

        testArgs.append("test")

        Herald.raw("# Run \(plan.displayName)")
        Herald.raw(CommandHelpers.formatCommand("xcodebuild", arguments: testArgs))
    }
}
