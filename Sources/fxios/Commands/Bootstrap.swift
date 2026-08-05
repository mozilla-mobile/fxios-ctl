// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import ArgumentParser
import Foundation

struct Bootstrap: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Bootstrap the firefox-ios repository for development.",
        discussion: """
            By default, bootstraps the product specified in .fxios.yaml (default_bootstrap),
            or Firefox if not configured. Use -p to override, or --all to bootstrap both.

            For either product, bootstrap will first install the SwiftLint version
            pinned in .swiftlint-version.

            For Firefox (-p firefox), bootstrap will:
              • Remove .venv directories
              • Download and run Nimbus FML bootstrap script
              • Install git hooks from .githooks/
              • Run npm install and npm run build

            For Focus (-p focus), bootstrap will:
              • Download and run Nimbus FML bootstrap script
              • Clone shavar-prod-lists repository
              • Build BrowserKit
            """
    )

    enum Product: String, ExpressibleByArgument, CaseIterable {
        case firefox
        case focus
    }

    @Option(name: [.short, .long], help: "Product to bootstrap: firefox or focus.")
    var product: Product?

    @Flag(name: .long, help: "Bootstrap both Firefox and Focus.")
    var all = false

    @Flag(name: .long, help: "Force a re-build by deleting the build directory. Only applies to firefox.")
    var force = false

    mutating func run() throws {
        // Validate we're in a firefox-ios repository and get repo root
        let repo = try RepoDetector.requireValidRepo()

        try ToolChecker.requireGit()
        try ToolChecker.requireNode()
        try ToolChecker.requireNpm()

        // Mirrors the install-swiftlint.sh call at the top of bootstrap.sh, which
        // runs ahead of the product branch and so applies to both products.
        Bootstrap.installPinnedSwiftlint(repoRoot: repo.root)

        if all {
            try bootstrapFirefox(repoRoot: repo.root)
            try bootstrapFocus(repoRoot: repo.root)
        } else {
            // Use explicit product or config default (which already has defaults applied)
            let resolvedProduct = product ?? Product(rawValue: repo.config.defaultBootstrap) ?? .firefox

            switch resolvedProduct {
            case .firefox:
                try bootstrapFirefox(repoRoot: repo.root)
            case .focus:
                try bootstrapFocus(repoRoot: repo.root)
            }
        }
    }

    private func bootstrapFirefox(repoRoot: URL) throws {
        Herald.declare("Running Firefox bootstrap...", isNewCommand: true)

        let fileManager = FileManager.default

        // Force rebuild: delete build directory
        if force {
            let buildDir = repoRoot.appendingPathComponent("build")
            if fileManager.fileExists(atPath: buildDir.path) {
                Herald.declare("Removing build directory...")
                try fileManager.removeItem(at: buildDir)
            }
        }

        // Delete all .venv folders
        Herald.declare("Cleaning up virtual environments...")
        try Bootstrap.deleteVenvFolders(in: repoRoot)

        // Download and run nimbus-fml bootstrap script
        Herald.declare("Setting up Nimbus FML...")
        let nimbusFmlFile = "./firefox-ios/nimbus.fml.yaml"
        try runNimbusBootstrap(
            nimbusFmlFile: nimbusFmlFile,
            extraArgs: ["--directory", "./firefox-ios/bin"],
            workingDirectory: repoRoot
        )

        // Copy git hooks
        Herald.declare("Installing git hooks...")
        try installGitHooks(repoRoot: repoRoot)

        // Run npm install and build
        Herald.declare("Installing Node.js dependencies...")
        try ShellRunner.run("npm", arguments: ["install"], workingDirectory: repoRoot)

        Herald.declare("Building user scripts...")
        try ShellRunner.run("npm", arguments: ["run", "build"], workingDirectory: repoRoot)

        Herald.declare("Firefox bootstrap complete!")
    }

    private func bootstrapFocus(repoRoot: URL) throws {
        Herald.declare("Running Focus bootstrap...", isNewCommand: true)

        let fileManager = FileManager.default
        let focusDir = repoRoot.appendingPathComponent("focus-ios")

        // Download and run nimbus-fml bootstrap script
        Herald.declare("Setting up Nimbus FML...")
        let nimbusFmlFile = "./nimbus.fml.yaml"
        try runNimbusBootstrap(
            nimbusFmlFile: nimbusFmlFile,
            workingDirectory: focusDir
        )

        // Clone shavar-prod-lists
        Herald.declare("Setting up shavar-prod-lists...")
        let shavarCommitHash = "91cf7dd142fc69aabe334a1a6e0091a1db228203"
        let shavarDir = repoRoot.appendingPathComponent("shavar-prod-lists")

        // Remove existing shavar-prod-lists if present
        if fileManager.fileExists(atPath: shavarDir.path) {
            try fileManager.removeItem(at: shavarDir)
        }

        try ShellRunner.run(
            "git",
            arguments: ["clone", "https://github.com/mozilla-services/shavar-prod-lists.git"],
            workingDirectory: repoRoot
        )
        try ShellRunner.run("git", arguments: [
            "-C", shavarDir.path,
            "checkout", shavarCommitHash
        ])

        // Run swift in BrowserKit
        Herald.declare("Building BrowserKit...")
        let browserKitDir = repoRoot.appendingPathComponent("BrowserKit")

        // MARK: - Swift retry logic
        // The original bootstrap script runs `swift run || true` followed by `swift run`.
        // This is because the first run may fail but sets up dependencies needed for the second run.
        do {
            try ShellRunner.run("swift", arguments: ["run"], workingDirectory: browserKitDir)
        } catch {
            Herald.declare("First `swift run` failed; this is an expected error. Rerunning...", asError: true)
            try ShellRunner.run("swift", arguments: ["run"], workingDirectory: browserKitDir)
        }

        Herald.declare("Focus bootstrap complete!")
    }

    // MARK: - SwiftLint

    /// Installs the SwiftLint version pinned in `.swiftlint-version`, matching the
    /// `./scripts/install-swiftlint.sh` call at the top of `bootstrap.sh`.
    ///
    /// Checkouts from before the script was added (older branches, release branches)
    /// are skipped rather than treated as an error, and a failed install only warns:
    /// `bootstrap.sh` does not set `-e`, so a download failure there leaves the rest
    /// of the bootstrap running too.
    static func installPinnedSwiftlint(repoRoot: URL) {
        let script = repoRoot.appendingPathComponent("scripts/install-swiftlint.sh")

        guard FileManager.default.fileExists(atPath: script.path) else {
            Herald.declare(
                "No scripts/install-swiftlint.sh in this checkout, skipping pinned SwiftLint.",
                isNewCommand: true
            )
            return
        }

        Herald.declare("Installing pinned SwiftLint...", isNewCommand: true)

        do {
            try ShellRunner.run(script.path, workingDirectory: repoRoot)
        } catch {
            Herald.declare(
                "Could not install the pinned SwiftLint version. Continuing; "
                    + "run scripts/install-swiftlint.sh to retry.",
                asError: true
            )
        }
    }

    // MARK: - Virtual Environments

    /// Directories that are never worth descending into when looking for `.venv`.
    /// `bootstrap.sh` lets `find` walk these, but they hold tens of thousands of
    /// files and cannot contain a Python virtual environment.
    static let venvSearchPruneList: Set<String> = [".git", "node_modules"]

    /// Removes every `.venv` directory under `directory`, matching
    /// `find . -type d -name ".venv" -exec rm -rf {} +` in `bootstrap.sh`.
    static func deleteVenvFolders(in directory: URL) throws {
        let fileManager = FileManager.default

        // Hidden files must not be skipped here: `.venv` is itself a dotfile, so
        // `.skipsHiddenFiles` would filter out every directory we are looking for.
        let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey]
        )

        var venvDirs: [URL] = []

        while let url = enumerator?.nextObject() as? URL {
            // A dangling symlink has no resource values; it is never a .venv either.
            guard let resourceValues = try? url.resourceValues(forKeys: [.isDirectoryKey]),
                  resourceValues.isDirectory == true else { continue }

            if url.lastPathComponent == ".venv" {
                venvDirs.append(url)
                enumerator?.skipDescendants()
            } else if venvSearchPruneList.contains(url.lastPathComponent) {
                enumerator?.skipDescendants()
            }
        }

        for venvDir in venvDirs {
            try fileManager.removeItem(at: venvDir)
        }
    }

    private func runNimbusBootstrap(
        nimbusFmlFile: String,
        extraArgs: [String] = [],
        workingDirectory: URL? = nil
    ) throws {
        let bootstrapURL = "https://raw.githubusercontent.com/mozilla/application-services/main/components/nimbus/ios/scripts/bootstrap.sh"

        // Download the script first (safer than piping directly to bash)
        let tempDir = FileManager.default.temporaryDirectory
        let scriptPath = tempDir.appendingPathComponent("nimbus-bootstrap-\(UUID().uuidString).sh")

        defer {
            try? FileManager.default.removeItem(at: scriptPath)
        }

        try ShellRunner.run("curl", arguments: [
            "--proto", "=https",
            "--tlsv1.2",
            "-sSf",
            "-o", scriptPath.path,
            bootstrapURL
        ])

        // Make executable
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: scriptPath.path
        )

        // Run the script
        let bashArgs = [scriptPath.path] + extraArgs + [nimbusFmlFile]
        try ShellRunner.run("bash", arguments: bashArgs, workingDirectory: workingDirectory)
    }

    private func installGitHooks(repoRoot: URL) throws {
        let fileManager = FileManager.default
        let gitHooksSource = repoRoot.appendingPathComponent(".githooks")
        let gitHooksDest = repoRoot.appendingPathComponent(".git/hooks")

        guard fileManager.fileExists(atPath: gitHooksSource.path) else {
            Herald.declare("No .githooks directory found, skipping hook installation.")
            return
        }

        let contents = try fileManager.contentsOfDirectory(
            at: gitHooksSource,
            includingPropertiesForKeys: nil
        )

        for sourceFile in contents {
            let destFile = gitHooksDest.appendingPathComponent(sourceFile.lastPathComponent)

            // Remove existing hook if present
            if fileManager.fileExists(atPath: destFile.path) {
                try fileManager.removeItem(at: destFile)
            }

            // Copy the hook
            try fileManager.copyItem(at: sourceFile, to: destFile)

            // Make executable
            try fileManager.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: destFile.path
            )
        }
    }
}
