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
}
