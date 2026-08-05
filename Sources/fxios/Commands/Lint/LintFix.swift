// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import ArgumentParser
import Foundation

extension Lint {
    struct Fix: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "fix",
            abstract: "Automatically correct fixable SwiftLint violations."
        )

        // MARK: - Scope

        @Flag(name: [.short, .long], help: "Fix only files changed compared to main branch.")
        var changed = false

        @Flag(name: [.short, .long], help: "Fix the entire codebase (default for fix).")
        var all = false

        @Flag(name: .long, help: "Print the commands instead of running them.")
        var expose = false

        // MARK: - Run

        mutating func run() throws {
            let repo = try RepoDetector.requireValidRepo()
            let swiftlint = try LintHelpers.resolveSwiftlint(repoRoot: repo.root)

            // For fix, default is --all unless --changed is specified
            let fixAll = !changed

            if expose {
                printExposedCommands(fixAll: fixAll, swiftlint: swiftlint)
                return
            }

            try runFix(fixAll: fixAll, repoRoot: repo.root, swiftlint: swiftlint)
        }

        // MARK: - Fix

        private func runFix(fixAll: Bool, repoRoot: URL, swiftlint: String) throws {
            let arguments: [String]

            if fixAll {
                Herald.declare("Fixing entire codebase...", isNewCommand: true)
                arguments = LintHelpers.lintArguments(fix: true)
            } else {
                Herald.declare("Fixing changed files...", isNewCommand: true)
                let changedFiles = try LintHelpers.getChangedSwiftFiles(repoRoot: repoRoot)

                if changedFiles.isEmpty {
                    Herald.declare("No changed Swift files found.")
                    return
                }

                Herald.declare("Found \(changedFiles.count) changed file(s)")
                arguments = LintHelpers.lintArguments(fix: true, files: changedFiles)
            }

            do {
                try ShellRunner.run(swiftlint, arguments: arguments, workingDirectory: repoRoot)
                Herald.declare("Fix complete!", asConclusion: true)
            } catch let error as ShellRunnerError {
                guard case .commandFailed(_, let exitCode) = error else { throw error }

                Herald.declare("Fix completed with issues (exit code \(exitCode))", asError: true, asConclusion: true)
            }
        }

        // MARK: - Expose Command

        private func printExposedCommands(fixAll: Bool, swiftlint: String) {
            if fixAll {
                Herald.raw("# Fix entire codebase")
                let args = LintHelpers.lintArguments(fix: true)
                Herald.raw(CommandHelpers.formatCommand(swiftlint, arguments: args))
            } else {
                Herald.raw("# Get merge base")
                Herald.raw("BASE=$(git merge-base HEAD main)")
                Herald.raw("")
                Herald.raw("# Find changed Swift files")
                let gitArgs = ["diff", "--name-only", "--diff-filter=ACMR", "$BASE...HEAD"]
                Herald.raw(CommandHelpers.formatCommand("git", arguments: gitArgs))
                Herald.raw("")

                let args = LintHelpers.lintArguments(fix: true, files: ["<files>"])

                Herald.raw("# Fix the changed files")
                Herald.raw(CommandHelpers.formatCommand(swiftlint, arguments: args))
            }
        }
    }
}
