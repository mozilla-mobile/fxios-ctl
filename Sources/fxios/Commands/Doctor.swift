// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import ArgumentParser
import Foundation

struct Doctor: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "doctor",
        abstract: "Check your development environment for required tools and configuration."
    )

    mutating func run() throws {
        Herald.declare("Checking development environment...", isNewCommand: true)
        Herald.declare("")

        var issues: [String] = []

        // Required tools
        checkTool("git", versionArgs: ["--version"], required: true, issues: &issues)
        checkTool("node", versionArgs: ["--version"], required: true, issues: &issues)
        checkTool("npm", versionArgs: ["--version"], required: true, issues: &issues)
        checkTool("swift", versionArgs: ["--version"], required: true, issues: &issues)
        checkXcode(issues: &issues)
        checkSimctl(issues: &issues)

        // Optional tools
        checkTool("swiftlint", versionArgs: ["version"], required: false, issues: &issues)

        Herald.declare("")

        // Repository context (optional)
        checkRepository(issues: &issues)

        Herald.declare("")

        // Summary
        if issues.isEmpty {
            Herald.declare("All checks passed! Your environment is ready for development.", asConclusion: true)
        } else {
            var issuesString = "Found \(issues.count) issue(s):\n"
            for issue in issues {
                issuesString.append(" • \(issue)\n")
            }
            Herald.declare("\(issuesString)", asError: true)
        }
    }

    // MARK: - Tool Checks

    private func checkTool(
        _ tool: String,
        versionArgs: [String],
        required: Bool,
        issues: inout [String]
    ) {
        let result = getToolVersion(tool, arguments: versionArgs)

        switch result {
        case .success(let version):
            let cleanVersion = version
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: .newlines)
                .first ?? version
            printCheck(passed: true, tool: tool, detail: cleanVersion)

        case .failure:
            printCheck(passed: false, tool: tool, detail: "not found")
            if required {
                issues.append("\(tool) is required but not installed")
            }
        }
    }

    private func checkXcode(issues: inout [String]) {
        // Check xcodebuild
        let xcodebuildResult = getToolVersion("xcodebuild", arguments: ["-version"])

        switch xcodebuildResult {
        case .success(let output):
            // Parse "Xcode X.X\nBuild version XXXXX" to get version
            let lines = output.trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: .newlines)
            let version = lines.first ?? output
            printCheck(passed: true, tool: "xcodebuild", detail: version)

        case .failure:
            printCheck(passed: false, tool: "xcodebuild", detail: "not found")
            issues.append("Xcode is required but not installed or xcode-select is not configured")
        }

        // Check xcode-select path
        let xcodeSelectResult = getToolVersion("xcode-select", arguments: ["-p"])

        switch xcodeSelectResult {
        case .success(let path):
            let cleanPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
            printCheck(passed: true, tool: "xcode-select", detail: cleanPath)

        case .failure:
            printCheck(passed: false, tool: "xcode-select", detail: "not configured")
            issues.append("xcode-select path not configured (run: sudo xcode-select -s /Applications/Xcode.app)")
        }
    }

    private func checkSimctl(issues: inout [String]) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["xcrun", "simctl", "help"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                printCheck(passed: true, tool: "simctl", detail: "available")
            } else {
                printCheck(passed: false, tool: "simctl", detail: "not available")
                issues.append("iOS Simulator tools (simctl) not available")
            }
        } catch {
            printCheck(passed: false, tool: "simctl", detail: "not available")
            issues.append("iOS Simulator tools (simctl) not available")
        }
    }

    // MARK: - Repository Checks

    private func checkRepository(issues: inout [String]) {
        Herald.declare("Repository status:")

        // Check if we're in a valid repo
        do {
            let repo = try RepoDetector.requireValidRepo()
            printCheck(passed: true, tool: "firefox-ios repo", detail: repo.root.path)

            // Check git hooks
            checkGitHooks(repoRoot: repo.root, issues: &issues)

            // Check the SwiftLint version the repository pins
            checkPinnedSwiftlint(repoRoot: repo.root, issues: &issues)

            // Display merged configuration (defaults are always present)
            printCheck(passed: true, tool: "default build", detail: repo.config.defaultBuildProduct)
            printCheck(passed: true, tool: "default bootstrap", detail: repo.config.defaultBootstrap)
        } catch {
            printCheck(passed: false, tool: "firefox-ios repo", detail: "not detected")
            Herald.declare("Run from a firefox-ios repository for full checks")
        }
    }

    private func checkGitHooks(repoRoot: URL, issues: inout [String]) {
        let fileManager = FileManager.default
        let gitHooksSource = repoRoot.appendingPathComponent(".githooks")
        let gitHooksDest = repoRoot.appendingPathComponent(".git/hooks")

        // Check if .githooks exists
        guard fileManager.fileExists(atPath: gitHooksSource.path) else {
            printCheck(passed: true, tool: "git hooks", detail: "no .githooks directory")
            return
        }

        // Check if hooks are installed
        do {
            let sourceHooks = try fileManager.contentsOfDirectory(
                at: gitHooksSource,
                includingPropertiesForKeys: nil
            )

            var missingHooks: [String] = []
            for sourceHook in sourceHooks {
                let hookName = sourceHook.lastPathComponent
                let destHook = gitHooksDest.appendingPathComponent(hookName)
                if !fileManager.fileExists(atPath: destHook.path) {
                    missingHooks.append(hookName)
                }
            }

            if missingHooks.isEmpty {
                printCheck(passed: true, tool: "git hooks", detail: "installed")
            } else {
                printCheck(passed: false, tool: "git hooks", detail: "missing: \(missingHooks.joined(separator: ", "))")
                issues.append("Git hooks not installed (run: fxios bootstrap)")
            }
        } catch {
            printCheck(passed: false, tool: "git hooks", detail: "could not check")
        }
    }

    /// Reports on the SwiftLint version pinned in `.swiftlint-version`.
    ///
    /// When it is missing, the Xcode build phases fall back to only printing a warning,
    /// so a build looks clean while linting nothing. That is worth flagging as an issue.
    /// A PATH install on a different version is only a note: `fxios lint` prefers the
    /// pinned binary, so the two disagreeing is confusing rather than broken.
    private func checkPinnedSwiftlint(repoRoot: URL, issues: inout [String]) {
        guard LintHelpers.hasInstallScript(repoRoot: repoRoot) else {
            printCheck(passed: true, tool: "pinned swiftlint", detail: "not used by this checkout")
            return
        }

        let script = repoRoot.appendingPathComponent(LintHelpers.installScriptPath).path
        let resolved = try? ShellRunner.runAndCapture(
            script,
            arguments: ["--path-only"],
            workingDirectory: repoRoot
        )

        guard let binary = resolved?.trimmingCharacters(in: .whitespacesAndNewlines),
              !binary.isEmpty else {
            printCheck(passed: false, tool: "pinned swiftlint", detail: "not installed")
            issues.append("Pinned SwiftLint not installed (run: fxios bootstrap)")
            return
        }

        let pinnedVersion = firstLine(of: getToolVersion(binary, arguments: ["version"]))
        printCheck(passed: true, tool: "pinned swiftlint", detail: pinnedVersion ?? binary)

        guard let pinnedVersion,
              let pathVersion = firstLine(of: getToolVersion("swiftlint", arguments: ["version"])),
              pathVersion != pinnedVersion else { return }

        Herald.declare(
            "Note: swiftlint \(pathVersion) is on your PATH but this repository pins "
                + "\(pinnedVersion). fxios lint uses the pinned one.",
            asError: true
        )
    }

    // MARK: - Helpers

    private func firstLine(of result: Result<String, Error>) -> String? {
        guard case .success(let output) = result else { return nil }

        let line = output
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .newlines)
            .first?
            .trimmingCharacters(in: .whitespaces)

        return (line?.isEmpty ?? true) ? nil : line
    }

    private func getToolVersion(_ tool: String, arguments: [String]) -> Result<String, Error> {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [tool] + arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus != 0 {
                return .failure(ToolCheckerError.toolNotFound(tool: tool, underlyingError: nil))
            }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return .success(output)
        } catch {
            return .failure(error)
        }
    }

    private func printCheck(passed: Bool, tool: String, detail: String) {
        let symbol = passed ? "✓" : "✗"
        let paddedTool = tool.padding(toLength: 18, withPad: " ", startingAt: 0)
        Herald.declare("\(symbol) \(paddedTool) \(detail)")
    }
}
