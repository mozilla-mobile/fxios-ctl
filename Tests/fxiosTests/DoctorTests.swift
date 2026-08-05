// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import ArgumentParser
import Foundation
import Testing
@testable import fxios

@Suite("Doctor Tests", .serialized)
struct DoctorTests {
    @Test("Command has correct name")
    func commandHasCorrectName() {
        #expect(Doctor.configuration.commandName == "doctor")
    }

    @Test("Command has non-empty abstract")
    func commandHasAbstract() {
        let abstract = Doctor.configuration.abstract
        #expect(!abstract.isEmpty)
    }

    @Test("Command can be parsed with no arguments")
    func canParseWithNoArguments() throws {
        let command = try Doctor.parse([])
        #expect(type(of: command) == Doctor.self)
    }

    @Test("Command is registered as subcommand of Fxios")
    func isRegisteredSubcommand() {
        let subcommands = Fxios.configuration.subcommands
        let doctorType = subcommands.first { $0 == Doctor.self }
        #expect(doctorType != nil)
    }

    // MARK: - Git Hook Status Tests

    @Test("gitHooksStatus returns nil without a .githooks directory")
    func gitHooksStatusWithoutSource() throws {
        try withTemporaryDirectory { tempDir in
            #expect(Doctor.gitHooksStatus(repoRoot: tempDir) == nil)
        }
    }

    @Test("gitHooksStatus reports installed hooks as up to date")
    func gitHooksStatusUpToDate() throws {
        try withTemporaryDirectory { tempDir in
            try makeHook(in: tempDir, named: "pre-push", contents: "#!/bin/sh\nexit 0\n")
            try installHook(in: tempDir, named: "pre-push", contents: "#!/bin/sh\nexit 0\n")

            let status = try #require(Doctor.gitHooksStatus(repoRoot: tempDir))

            #expect(status.isUpToDate)
            #expect(status.missing.isEmpty)
            #expect(status.stale.isEmpty)
        }
    }

    @Test("gitHooksStatus reports uninstalled hooks as missing")
    func gitHooksStatusMissing() throws {
        try withTemporaryDirectory { tempDir in
            try makeHook(in: tempDir, named: "pre-push", contents: "#!/bin/sh\nexit 0\n")

            let status = try #require(Doctor.gitHooksStatus(repoRoot: tempDir))

            #expect(status.missing == ["pre-push"])
            #expect(status.stale.isEmpty)
            #expect(!status.isUpToDate)
        }
    }

    @Test("gitHooksStatus reports an outdated copy as stale")
    func gitHooksStatusStale() throws {
        try withTemporaryDirectory { tempDir in
            // Bootstrap copies rather than symlinks, so pulling a hook change leaves
            // the installed copy on the old revision.
            try makeHook(in: tempDir, named: "pre-push", contents: "#!/bin/sh\n\"$SWIFTLINT\" --strict\n")
            try installHook(in: tempDir, named: "pre-push", contents: "#!/bin/sh\nswiftlint --strict\n")

            let status = try #require(Doctor.gitHooksStatus(repoRoot: tempDir))

            #expect(status.stale == ["pre-push"])
            #expect(status.missing.isEmpty)
            #expect(!status.isUpToDate)
        }
    }

    @Test("gitHooksStatus separates missing hooks from stale ones")
    func gitHooksStatusMixed() throws {
        try withTemporaryDirectory { tempDir in
            try makeHook(in: tempDir, named: "pre-push", contents: "new\n")
            try installHook(in: tempDir, named: "pre-push", contents: "old\n")
            try makeHook(in: tempDir, named: "pre-commit", contents: "new\n")

            let status = try #require(Doctor.gitHooksStatus(repoRoot: tempDir))

            #expect(status.missing == ["pre-commit"])
            #expect(status.stale == ["pre-push"])
        }
    }

    @Test("gitHooksStatus reports hook names in a stable order")
    func gitHooksStatusIsOrdered() throws {
        try withTemporaryDirectory { tempDir in
            for name in ["pre-push", "commit-msg", "pre-commit"] {
                try makeHook(in: tempDir, named: name, contents: "new\n")
            }

            let status = try #require(Doctor.gitHooksStatus(repoRoot: tempDir))

            #expect(status.missing == ["commit-msg", "pre-commit", "pre-push"])
        }
    }

    @Test("gitHooksStatus ignores directories inside .githooks")
    func gitHooksStatusIgnoresDirectories() throws {
        try withTemporaryDirectory { tempDir in
            try makeDirectory(at: tempDir, path: ".githooks/helpers")
            try makeDirectory(at: tempDir, path: ".git/hooks/helpers")

            let status = try #require(Doctor.gitHooksStatus(repoRoot: tempDir))

            // Present on both sides and not comparable as bytes, so not stale.
            #expect(status.isUpToDate)
        }
    }
}

// MARK: - Fixtures

/// Writes a hook into the repository's tracked .githooks directory.
private func makeHook(in repoRoot: URL, named name: String, contents: String) throws {
    let hooks = try makeDirectory(at: repoRoot, path: ".githooks")
    try contents.write(to: hooks.appendingPathComponent(name), atomically: true, encoding: .utf8)
}

/// Writes a hook into the repository's installed .git/hooks directory.
private func installHook(in repoRoot: URL, named name: String, contents: String) throws {
    let hooks = try makeDirectory(at: repoRoot, path: ".git/hooks")
    try contents.write(to: hooks.appendingPathComponent(name), atomically: true, encoding: .utf8)
}
