// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import ArgumentParser
import Foundation
import Testing
@testable import fxios

@Suite("Lint Tests", .serialized)
struct LintTests {
    // MARK: - Command Configuration Tests

    @Test("Command has correct name")
    func commandName() {
        #expect(Lint.configuration.commandName == "lint")
    }

    @Test("Command has non-empty abstract")
    func commandHasAbstract() {
        let abstract = Lint.configuration.abstract
        #expect(!abstract.isEmpty)
    }

    @Test("Command has discussion text")
    func commandHasDiscussion() {
        let discussion = Lint.configuration.discussion
        #expect(!discussion.isEmpty)
    }

    @Test("Command has three subcommands")
    func hasSubcommands() {
        let subcommands = Lint.configuration.subcommands
        #expect(subcommands.count == 3)
        #expect(subcommands.contains { $0 == Lint.Run.self })
        #expect(subcommands.contains { $0 == Lint.Fix.self })
        #expect(subcommands.contains { $0 == Lint.Info.self })
    }

    @Test("Command has no default subcommand")
    func hasNoDefaultSubcommand() {
        #expect(Lint.configuration.defaultSubcommand == nil)
    }

    // MARK: - Run Subcommand Tests

    @Test("Run subcommand has correct name")
    func runCommandName() {
        #expect(Lint.Run.configuration.commandName == "run")
    }

    @Test("Run subcommand has non-empty abstract")
    func runHasAbstract() {
        let abstract = Lint.Run.configuration.abstract
        #expect(!abstract.isEmpty)
    }

    @Test("Run can parse --changed flag")
    func runParseChangedFlag() throws {
        let command = try Lint.Run.parse(["--changed"])
        #expect(command.changed == true)
    }

    @Test("Run can parse --strict flag")
    func runParseStrictFlag() throws {
        let command = try Lint.Run.parse(["--strict"])
        #expect(command.strict == true)
    }

    @Test("Run can parse --quiet flag short form")
    func runParseQuietShort() throws {
        let command = try Lint.Run.parse(["-q"])
        #expect(command.quiet == true)
    }

    @Test("Run can parse --quiet flag long form")
    func runParseQuietLong() throws {
        let command = try Lint.Run.parse(["--quiet"])
        #expect(command.quiet == true)
    }

    @Test("Run can parse --expose flag")
    func runParseExposeFlag() throws {
        let command = try Lint.Run.parse(["--expose"])
        #expect(command.expose == true)
    }

    @Test("Run can parse multiple flags together")
    func runParseMultipleFlags() throws {
        let command = try Lint.Run.parse(["--changed", "--strict", "-q"])
        #expect(command.changed == true)
        #expect(command.strict == true)
        #expect(command.quiet == true)
    }

    // MARK: - Run swiftlintFlags Tests

    @Test("Run swiftlintFlags returns empty array by default")
    func runSwiftlintFlagsDefault() throws {
        let command = try Lint.Run.parse([])
        #expect(command.swiftlintFlags().isEmpty)
    }

    @Test("Run swiftlintFlags includes --quiet when quiet is set")
    func runSwiftlintFlagsQuiet() throws {
        let command = try Lint.Run.parse(["--quiet"])
        let flags = command.swiftlintFlags()
        #expect(flags.contains("--quiet"))
        #expect(!flags.contains("--strict"))
    }

    @Test("Run swiftlintFlags includes --strict when strict is set")
    func runSwiftlintFlagsStrict() throws {
        let command = try Lint.Run.parse(["--strict"])
        let flags = command.swiftlintFlags()
        #expect(flags.contains("--strict"))
        #expect(!flags.contains("--quiet"))
    }

    @Test("Run swiftlintFlags includes both flags when both are set")
    func runSwiftlintFlagsBoth() throws {
        let command = try Lint.Run.parse(["--strict", "--quiet"])
        let flags = command.swiftlintFlags()
        #expect(flags.contains("--strict"))
        #expect(flags.contains("--quiet"))
    }

    // MARK: - Fix Subcommand Tests

    @Test("Fix subcommand has correct name")
    func fixCommandName() {
        #expect(Lint.Fix.configuration.commandName == "fix")
    }

    @Test("Fix subcommand has non-empty abstract")
    func fixHasAbstract() {
        let abstract = Lint.Fix.configuration.abstract
        #expect(!abstract.isEmpty)
    }

    @Test("Fix can parse --changed flag")
    func fixParseChangedFlag() throws {
        let command = try Lint.Fix.parse(["--changed"])
        #expect(command.changed == true)
    }

    @Test("Fix can parse --all flag")
    func fixParseAllFlag() throws {
        let command = try Lint.Fix.parse(["--all"])
        #expect(command.all == true)
    }

    @Test("Fix can parse --expose flag")
    func fixParseExposeFlag() throws {
        let command = try Lint.Fix.parse(["--expose"])
        #expect(command.expose == true)
    }

    // MARK: - Info Subcommand Tests

    @Test("Info subcommand has correct name")
    func infoCommandName() {
        #expect(Lint.Info.configuration.commandName == "info")
    }

    @Test("Info subcommand has non-empty abstract")
    func infoHasAbstract() {
        let abstract = Lint.Info.configuration.abstract
        #expect(!abstract.isEmpty)
    }

    // MARK: - LintError Tests

    @Test("LintError.swiftlintNotFound has correct description")
    func swiftlintNotFoundError() {
        let error = LintError.swiftlintNotFound
        #expect(error.description.contains("swiftlint not found"))
    }

    @Test("LintError.swiftlintNotFound points at bootstrap, not Homebrew")
    func swiftlintNotFoundRecommendsBootstrap() {
        // firefox-ios CONTRIBUTING.md asks contributors not to brew install SwiftLint.
        let error = LintError.swiftlintNotFound
        #expect(error.description.contains("fxios bootstrap"))
        #expect(!error.description.lowercased().contains("brew"))
    }

    @Test("LintError.lintFailed has correct description")
    func lintFailedError() {
        let error = LintError.lintFailed(exitCode: 1)
        #expect(error.description.contains("failed"))
        #expect(error.description.contains("1"))
    }

    @Test("LintError.noChangedFiles has correct description")
    func noChangedFilesError() {
        let error = LintError.noChangedFiles
        #expect(error.description.contains("No changed"))
    }

    // MARK: - Invocation Building Tests

    @Test("lintArguments uses the lint subcommand")
    func lintArgumentsUsesLintSubcommand() {
        #expect(LintHelpers.lintArguments() == ["lint"])
    }

    @Test("lintArguments never passes --config")
    func lintArgumentsOmitsConfig() {
        // firefox-ios has nested .swiftlint.yml files under focus-ios and
        // BrowserKit/Tests; an explicit --config would suppress them, and neither
        // the Xcode build phases nor CI pass one.
        let args = LintHelpers.lintArguments(flags: ["--strict"], files: ["/repo/A.swift"])
        #expect(!args.contains("--config"))
        #expect(!args.contains { $0.hasSuffix(".swiftlint.yml") || $0.hasSuffix(".swiftlint.yaml") })
    }

    @Test("lintArguments never passes --path")
    func lintArgumentsOmitsPath() {
        // SwiftLint removed --path; files are positional.
        let args = LintHelpers.lintArguments(files: ["/repo/A.swift", "/repo/B.swift"])
        #expect(!args.contains("--path"))
    }

    @Test("lintArguments passes every file in one invocation")
    func lintArgumentsBatchesFiles() {
        let files = ["/repo/A.swift", "/repo/B.swift", "/repo/C.swift"]
        let args = LintHelpers.lintArguments(files: files)
        #expect(args == ["lint"] + files)
    }

    @Test("lintArguments orders flags before files")
    func lintArgumentsOrdersFlagsBeforeFiles() {
        let args = LintHelpers.lintArguments(flags: ["--strict", "--quiet"], files: ["/repo/A.swift"])
        #expect(args == ["lint", "--strict", "--quiet", "/repo/A.swift"])
    }

    @Test("lintArguments includes --fix when fixing")
    func lintArgumentsIncludesFix() {
        let args = LintHelpers.lintArguments(fix: true, files: ["/repo/A.swift"])
        #expect(args == ["lint", "--fix", "/repo/A.swift"])
    }

    @Test("lintArguments omits --fix when linting")
    func lintArgumentsOmitsFix() {
        #expect(!LintHelpers.lintArguments(files: ["/repo/A.swift"]).contains("--fix"))
    }

    // MARK: - SwiftLint Resolution Tests

    @Test("hasInstallScript detects the pinned installer")
    func hasInstallScriptDetectsInstaller() throws {
        try withTemporaryDirectory { tempDir in
            #expect(!LintHelpers.hasInstallScript(repoRoot: tempDir))

            try makeInstallSwiftlintScript(in: tempDir, body: "exit 0")

            #expect(LintHelpers.hasInstallScript(repoRoot: tempDir))
        }
    }

    @Test("pinnedSwiftlintPath returns the already-installed binary")
    func pinnedSwiftlintPathUsesPathOnly() throws {
        try withTemporaryDirectory { tempDir in
            // --path-only succeeds when .tools already holds the pinned version.
            try makeInstallSwiftlintScript(in: tempDir, body: "echo /repo/.tools/swiftlint/0.65.0/swiftlint")

            let resolved = LintHelpers.pinnedSwiftlintPath(repoRoot: tempDir)

            #expect(resolved == "/repo/.tools/swiftlint/0.65.0/swiftlint")
        }
    }

    @Test("pinnedSwiftlintPath installs when the binary is missing")
    func pinnedSwiftlintPathInstallsWhenMissing() throws {
        try withTemporaryDirectory { tempDir in
            // --path-only exits 1 without downloading; a bare run installs and prints.
            try makeInstallSwiftlintScript(in: tempDir, body: """
                if [ "$1" = "--path-only" ]; then exit 1; fi
                echo "Installing SwiftLint 0.65.0." >&2
                echo /repo/.tools/swiftlint/0.65.0/swiftlint
                """)

            let resolved = LintHelpers.pinnedSwiftlintPath(repoRoot: tempDir)

            #expect(resolved == "/repo/.tools/swiftlint/0.65.0/swiftlint")
        }
    }

    @Test("pinnedSwiftlintPath ignores progress output on stderr")
    func pinnedSwiftlintPathIgnoresStderr() throws {
        try withTemporaryDirectory { tempDir in
            try makeInstallSwiftlintScript(in: tempDir, body: """
                echo "SwiftLint 0.65.0 already installed." >&2
                echo /repo/.tools/swiftlint/0.65.0/swiftlint
                """)

            #expect(LintHelpers.pinnedSwiftlintPath(repoRoot: tempDir)
                == "/repo/.tools/swiftlint/0.65.0/swiftlint")
        }
    }

    @Test("pinnedSwiftlintPath returns nil when the installer fails")
    func pinnedSwiftlintPathReturnsNilOnFailure() throws {
        try withTemporaryDirectory { tempDir in
            // A checksum mismatch or a network failure exits non-zero both times.
            try makeInstallSwiftlintScript(in: tempDir, body: "echo 'checksum mismatch' >&2\nexit 1")

            #expect(LintHelpers.pinnedSwiftlintPath(repoRoot: tempDir) == nil)
        }
    }

    @Test("pinnedSwiftlintPath returns nil when the installer prints nothing")
    func pinnedSwiftlintPathReturnsNilOnEmptyOutput() throws {
        try withTemporaryDirectory { tempDir in
            try makeInstallSwiftlintScript(in: tempDir, body: "exit 0")

            #expect(LintHelpers.pinnedSwiftlintPath(repoRoot: tempDir) == nil)
        }
    }

    @Test("resolveSwiftlint prefers the pinned binary over PATH")
    func resolveSwiftlintPrefersPinned() throws {
        try withTemporaryDirectory { tempDir in
            try makeInstallSwiftlintScript(in: tempDir, body: "echo /repo/.tools/swiftlint/0.65.0/swiftlint")

            let resolved = try LintHelpers.resolveSwiftlint(repoRoot: tempDir)

            #expect(resolved == "/repo/.tools/swiftlint/0.65.0/swiftlint")
        }
    }

    @Test(
        "resolveSwiftlint falls back to PATH without an installer",
        .enabled(if: pathSwiftlintAvailable, "requires swiftlint on PATH")
    )
    func resolveSwiftlintFallsBackToPath() throws {
        // Checkouts predating the pin have no installer, so PATH is all there is.
        try withTemporaryDirectory { tempDir in
            let resolved = try LintHelpers.resolveSwiftlint(repoRoot: tempDir)
            #expect(resolved == "swiftlint")
        }
    }

    @Test(
        "resolveSwiftlint throws when no SwiftLint can be found",
        .disabled(if: pathSwiftlintAvailable, "swiftlint on PATH would satisfy the fallback")
    )
    func resolveSwiftlintThrowsWhenUnavailable() throws {
        try withTemporaryDirectory { tempDir in
            #expect(throws: LintError.self) {
                _ = try LintHelpers.resolveSwiftlint(repoRoot: tempDir)
            }
        }
    }
}

/// Whether SwiftLint is on PATH. The fallback branch of `resolveSwiftlint` can only
/// be exercised one way or the other depending on the machine running the suite.
private let pathSwiftlintAvailable =
    (try? ShellRunner.runAndCapture("which", arguments: ["swiftlint"])) != nil
