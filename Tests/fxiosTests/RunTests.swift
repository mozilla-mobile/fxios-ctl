// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import ArgumentParser
import Foundation
import Testing
@testable import fxios

@Suite("Run Tests", .serialized)
struct RunTests {
    // MARK: - Command Configuration Tests

    @Test("Command has correct name")
    func commandName() {
        #expect(Run.configuration.commandName == "run")
    }

    @Test("Command has non-empty abstract")
    func commandHasAbstract() {
        let abstract = Run.configuration.abstract
        #expect(!abstract.isEmpty)
    }

    @Test("Command has discussion text")
    func commandHasDiscussion() {
        let discussion = Run.configuration.discussion
        #expect(!discussion.isEmpty)
        #expect(discussion.lowercased().contains("simulator"))
    }

    // MARK: - Argument Parsing Tests

    @Test("Can parse product option short form")
    func parseProductShort() throws {
        let command = try Run.parse(["-p", "focus"])
        #expect(command.product == .focus)
    }

    @Test("Can parse product option long form")
    func parseProductLong() throws {
        let command = try Run.parse(["--product", "klar"])
        #expect(command.product == .klar)
    }

    @Test("Can parse sim option")
    func parseSim() throws {
        let command = try Run.parse(["--sim", "17pro"])
        #expect(command.sim == "17pro")
    }

    @Test("Can parse os option")
    func parseOs() throws {
        let command = try Run.parse(["--os", "18.2"])
        #expect(command.os == "18.2")
    }

    @Test("Can parse configuration option")
    func parseConfiguration() throws {
        let command = try Run.parse(["--configuration", "Fennec"])
        #expect(command.configuration == "Fennec")
    }

    @Test("Can parse derived-data option")
    func parseDerivedData() throws {
        let command = try Run.parse(["--derived-data", "/tmp/DD"])
        #expect(command.derivedData == "/tmp/DD")
    }

    @Test("Can parse doNotSkipMacroValidation flag")
    func parseDoNotSkipMacroValidation() throws {
        let command = try Run.parse(["--doNotSkipMacroValidation"])
        #expect(command.doNotSkipMacroValidation == true)
        #expect(command.skipMacroValidation == false)
    }

    @Test("Can parse skip-resolve flag")
    func parseSkipResolve() throws {
        let command = try Run.parse(["--skip-resolve"])
        #expect(command.skipResolve == true)
    }

    @Test("Can parse clean flag")
    func parseClean() throws {
        let command = try Run.parse(["--clean"])
        #expect(command.clean == true)
    }

    @Test("Can parse quiet flag short form")
    func parseQuietShort() throws {
        let command = try Run.parse(["-q"])
        #expect(command.quiet == true)
    }

    @Test("Can parse quiet flag long form")
    func parseQuietLong() throws {
        let command = try Run.parse(["--quiet"])
        #expect(command.quiet == true)
    }

    @Test("Can parse expose flag")
    func parseExpose() throws {
        let command = try Run.parse(["--expose"])
        #expect(command.expose == true)
    }

    @Test("Default values are correct")
    func defaultValues() throws {
        let command = try Run.parse([])
        #expect(command.product == nil)
        #expect(command.sim == nil)
        #expect(command.os == nil)
        #expect(command.configuration == nil)
        #expect(command.derivedData == nil)
        #expect(command.doNotSkipMacroValidation == false)
        #expect(command.skipMacroValidation == true)
        #expect(command.skipResolve == false)
        #expect(command.clean == false)
        #expect(command.quiet == false)
        #expect(command.expose == false)
    }

    @Test("Can combine multiple flags")
    func combineFlags() throws {
        let command = try Run.parse(["-p", "focus", "--clean", "-q"])
        #expect(command.product == .focus)
        #expect(command.clean == true)
        #expect(command.quiet == true)
    }

    // MARK: - Repository Validation Tests

    @Test("run throws when not in git repo")
    func runThrowsWhenNotInGitRepo() throws {
        let tempDir = try createTempDirectory()
        defer { cleanup(tempDir) }

        let originalDir = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(tempDir.path)
        defer { FileManager.default.changeCurrentDirectoryPath(originalDir) }

        var command = try Run.parse([])
        #expect(throws: RepoDetectorError.self) {
            try command.run()
        }
    }

    @Test("run throws when marker file missing")
    func runThrowsWhenMarkerMissing() throws {
        let repoDir = try createTempGitRepo()
        defer { cleanup(repoDir) }

        let originalDir = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(repoDir.path)
        defer { FileManager.default.changeCurrentDirectoryPath(originalDir) }

        var command = try Run.parse([])
        #expect(throws: RepoDetectorError.self) {
            try command.run()
        }
    }
}
