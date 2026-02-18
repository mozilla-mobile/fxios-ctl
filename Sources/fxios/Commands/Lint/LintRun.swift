// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import ArgumentParser
import Foundation

extension Lint {
    struct Run: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "run",
            abstract: "Run SwiftLint to check for violations (default)."
        )

        // MARK: - Scope

        @Flag(name: [.short, .long], help: "Lint only files changed compared to main branch.")
        var changed = false

        // MARK: - Options

        @Flag(name: [.short, .long], help: "Treat warnings as errors.")
        var strict = false

        @Flag(name: [.short, .long], help: "Show only violation counts.")
        var quiet = false

        @Flag(name: .long, help: "Print the commands instead of running them.")
        var expose = false

        // MARK: - Run

        mutating func run() throws {
            let repo = try RepoDetector.requireValidRepo()
            try LintHelpers.requireSwiftlint()

            // Default is all (unless --changed is specified)
            let lintAll = !changed

            if expose {
                printExposedCommands(lintAll: lintAll, repoRoot: repo.root)
                return
            }

            try runLint(lintAll: lintAll, repoRoot: repo.root)
        }

        // MARK: - Flags

        /// Builds the swiftlint flag arguments based on parsed options.
        func swiftlintFlags() -> [String] {
            var flags: [String] = []
            if strict { flags.append("--strict") }
            if quiet { flags.append("--quiet") }
            return flags
        }

        // MARK: - Lint

        private func runLint(lintAll: Bool, repoRoot: URL) throws {
            if lintAll {
                Herald.declare("Linting entire codebase...", isNewCommand: true)

                do {
                    try ShellRunner.run("swiftlint", arguments: swiftlintFlags(), workingDirectory: repoRoot)
                    Herald.declare("Linting complete!", asConclusion: true)
                } catch let error as ShellRunnerError {
                    if case .commandFailed(_, let exitCode) = error {
                        if strict {
                            throw LintError.lintFailed(exitCode: exitCode)
                        }
                        Herald.declare("Linting found violations (exit code \(exitCode))", asError: true, asConclusion: true)
                    } else {
                        throw error
                    }
                }
            } else {
                Herald.declare("Linting changed files...", isNewCommand: true)
                let changedFiles = try LintHelpers.getChangedSwiftFiles(repoRoot: repoRoot)

                if changedFiles.isEmpty {
                    Herald.declare("No changed Swift files found.")
                    return
                }

                Herald.declare("Found \(changedFiles.count) changed file(s)")

                let configPath = repoRoot.appendingPathComponent(".swiftlint.yaml").path

                var hasViolations = false
                for file in changedFiles {
                    var args: [String] = ["lint", "--config", configPath, "--path", file]
                    args.append(contentsOf: swiftlintFlags())

                    do {
                        try ShellRunner.run("swiftlint", arguments: args, workingDirectory: repoRoot)
                    } catch let error as ShellRunnerError {
                        if case .commandFailed(_, let exitCode) = error {
                            hasViolations = true
                            if strict {
                                throw LintError.lintFailed(exitCode: exitCode)
                            }
                        } else {
                            throw error
                        }
                    }
                }

                if hasViolations {
                    Herald.declare("Linting found violations", asError: true, asConclusion: true)
                } else {
                    Herald.declare("Linting complete!", asConclusion: true)
                }
            }
        }

        // MARK: - Expose Command

        private func printExposedCommands(lintAll: Bool, repoRoot: URL) {
            if lintAll {
                Herald.raw("# Lint entire codebase")
                Herald.raw(CommandHelpers.formatCommand("swiftlint", arguments: swiftlintFlags()))
            } else {
                let configPath = repoRoot.appendingPathComponent(".swiftlint.yaml").path

                Herald.raw("# Get merge base")
                Herald.raw("BASE=$(git merge-base HEAD main)")
                Herald.raw("")
                Herald.raw("# Find changed Swift files")
                let gitArgs = ["diff", "--name-only", "--diff-filter=ACMR", "$BASE...HEAD"]
                Herald.raw(CommandHelpers.formatCommand("git", arguments: gitArgs))
                Herald.raw("")

                var args: [String] = ["lint", "--config", configPath, "--path", "<file>"]
                args.append(contentsOf: swiftlintFlags())

                Herald.raw("# Lint each changed file")
                Herald.raw(CommandHelpers.formatCommand("swiftlint", arguments: args))
            }
        }
    }
}
