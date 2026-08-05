// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import ArgumentParser
import Foundation
import Testing
@testable import fxios

@Suite("Bootstrap Tests", .serialized)
struct BootstrapTests {
    // MARK: - Command Configuration Tests

    @Test("Command has non-empty abstract")
    func commandHasAbstract() {
        let abstract = Bootstrap.configuration.abstract
        #expect(!abstract.isEmpty)
    }

    @Test("Command has discussion text")
    func commandHasDiscussion() {
        let discussion = Bootstrap.configuration.discussion
        #expect(!discussion.isEmpty)
        #expect(discussion.contains("Firefox"))
        #expect(discussion.contains("Focus"))
        #expect(discussion.contains(".swiftlint-version"))
    }

    // MARK: - Product Enum Tests

    @Test("Product enum has firefox case")
    func productHasFirefox() {
        let product = Bootstrap.Product(rawValue: "firefox")
        #expect(product == .firefox)
    }

    @Test("Product enum has focus case")
    func productHasFocus() {
        let product = Bootstrap.Product(rawValue: "focus")
        #expect(product == .focus)
    }

    @Test("Product enum raw values are correct")
    func productRawValues() {
        #expect(Bootstrap.Product.firefox.rawValue == "firefox")
        #expect(Bootstrap.Product.focus.rawValue == "focus")
    }

    @Test("Product enum has exactly two cases")
    func productCaseCount() {
        #expect(Bootstrap.Product.allCases.count == 2)
    }

    // MARK: - Repository Validation Tests

    @Test("run throws when not in firefox-ios repo")
    func runThrowsWhenNotInRepo() throws {
        let tempDir = try createTempDirectory()
        defer { cleanup(tempDir) }

        let originalDir = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(tempDir.path)
        defer { FileManager.default.changeCurrentDirectoryPath(originalDir) }

        var command = try Bootstrap.parse(["--all"])
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

        var command = try Bootstrap.parse(["--all"])
        #expect(throws: RepoDetectorError.self) {
            try command.run()
        }
    }

    // MARK: - Default Bootstrap Config Tests

    @Test("Config with default_bootstrap firefox is parsed correctly")
    func configWithFirefoxDefault() throws {
        let tempDir = try createTempDirectory()
        defer { cleanup(tempDir) }

        let markerPath = tempDir.appendingPathComponent(Configuration.markerFileName)
        let yaml = """
            project: firefox-ios
            default_bootstrap: firefox
            """
        try yaml.write(to: markerPath, atomically: true, encoding: .utf8)

        let config = try RepoDetector.loadConfig(from: markerPath)
        #expect(config.defaultBootstrap == "firefox")
    }

    @Test("Config with default_bootstrap focus is parsed correctly")
    func configWithFocusDefault() throws {
        let tempDir = try createTempDirectory()
        defer { cleanup(tempDir) }

        let markerPath = tempDir.appendingPathComponent(Configuration.markerFileName)
        let yaml = """
            project: firefox-ios
            default_bootstrap: focus
            """
        try yaml.write(to: markerPath, atomically: true, encoding: .utf8)

        let config = try RepoDetector.loadConfig(from: markerPath)
        #expect(config.defaultBootstrap == "focus")
    }

    @Test("Config without default_bootstrap has nil value")
    func configWithoutDefaultBootstrap() throws {
        let tempDir = try createTempDirectory()
        defer { cleanup(tempDir) }

        let markerPath = tempDir.appendingPathComponent(Configuration.markerFileName)
        try "project: firefox-ios".write(to: markerPath, atomically: true, encoding: .utf8)

        let config = try RepoDetector.loadConfig(from: markerPath)
        #expect(config.defaultBootstrap == nil)
    }

    // MARK: - Virtual Environment Cleanup Tests

    @Test("deleteVenvFolders removes .venv at the repository root")
    func deleteVenvAtRoot() throws {
        try withTemporaryDirectory { tempDir in
            let venv = try makeDirectory(at: tempDir, path: ".venv")
            try makeFile(at: venv, named: "pyvenv.cfg")

            try Bootstrap.deleteVenvFolders(in: tempDir)

            #expect(!exists(venv))
        }
    }

    @Test("deleteVenvFolders removes nested .venv directories")
    func deleteNestedVenvs() throws {
        try withTemporaryDirectory { tempDir in
            let shallow = try makeDirectory(at: tempDir, path: "firefox-ios/.venv")
            let deep = try makeDirectory(at: tempDir, path: "a/b/c/.venv")
            try makeFile(at: deep, named: "pyvenv.cfg")

            try Bootstrap.deleteVenvFolders(in: tempDir)

            #expect(!exists(shallow))
            #expect(!exists(deep))
            // Only the .venv directories go; their parents stay.
            #expect(exists(tempDir.appendingPathComponent("a/b/c")))
        }
    }

    @Test("deleteVenvFolders leaves other hidden directories alone")
    func deleteVenvKeepsOtherHiddenDirs() throws {
        try withTemporaryDirectory { tempDir in
            let hidden = try makeDirectory(at: tempDir, path: ".githooks")
            let venv = try makeDirectory(at: tempDir, path: ".venv")

            try Bootstrap.deleteVenvFolders(in: tempDir)

            #expect(!exists(venv))
            #expect(exists(hidden))
        }
    }

    @Test("deleteVenvFolders ignores a file named .venv")
    func deleteVenvIgnoresFiles() throws {
        try withTemporaryDirectory { tempDir in
            // bootstrap.sh matches with `find -type d`, so a plain file survives.
            try makeFile(at: tempDir, named: ".venv")

            try Bootstrap.deleteVenvFolders(in: tempDir)

            #expect(exists(tempDir.appendingPathComponent(".venv")))
        }
    }

    @Test("deleteVenvFolders does not descend into pruned directories")
    func deleteVenvPrunesHeavyDirectories() throws {
        try withTemporaryDirectory { tempDir in
            var pruned: [URL] = []
            for name in Bootstrap.venvSearchPruneList {
                pruned.append(try makeDirectory(at: tempDir, path: "\(name)/.venv"))
            }
            let real = try makeDirectory(at: tempDir, path: ".venv")

            try Bootstrap.deleteVenvFolders(in: tempDir)

            #expect(!exists(real))
            for url in pruned {
                #expect(exists(url))
            }
        }
    }

    @Test("deleteVenvFolders succeeds when there is nothing to remove")
    func deleteVenvWithNoMatches() throws {
        try withTemporaryDirectory { tempDir in
            try makeFile(at: tempDir, named: "README.md")

            try Bootstrap.deleteVenvFolders(in: tempDir)

            #expect(exists(tempDir.appendingPathComponent("README.md")))
        }
    }

    // MARK: - Pinned SwiftLint Tests

    @Test("installPinnedSwiftlint runs the repository script")
    func installPinnedSwiftlintRunsScript() throws {
        try withTemporaryDirectory { tempDir in
            try makeInstallSwiftlintScript(in: tempDir, body: "touch \"$(dirname \"$0\")/../ran\"")

            Bootstrap.installPinnedSwiftlint(repoRoot: tempDir)

            #expect(exists(tempDir.appendingPathComponent("ran")))
        }
    }

    @Test("installPinnedSwiftlint runs the script from the repository root")
    func installPinnedSwiftlintUsesRepoRootAsWorkingDirectory() throws {
        try withTemporaryDirectory { tempDir in
            // bootstrap.sh invokes the script as ./scripts/install-swiftlint.sh,
            // so it always resolves relative paths against the repo root.
            try makeInstallSwiftlintScript(in: tempDir, body: "pwd > cwd.txt")

            Bootstrap.installPinnedSwiftlint(repoRoot: tempDir)

            let recorded = try String(contentsOf: tempDir.appendingPathComponent("cwd.txt"), encoding: .utf8)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            #expect(URL(fileURLWithPath: recorded).resolvingSymlinksInPath()
                == tempDir.resolvingSymlinksInPath())
        }
    }

    @Test("installPinnedSwiftlint skips checkouts without the script")
    func installPinnedSwiftlintSkipsWhenScriptMissing() throws {
        try withTemporaryDirectory { tempDir in
            // Branches predating the pin have no scripts/install-swiftlint.sh.
            Bootstrap.installPinnedSwiftlint(repoRoot: tempDir)

            #expect(!exists(tempDir.appendingPathComponent("scripts")))
        }
    }

    @Test("installPinnedSwiftlint tolerates a failing script")
    func installPinnedSwiftlintToleratesFailure() throws {
        try withTemporaryDirectory { tempDir in
            // bootstrap.sh has no `set -e`, so a checksum mismatch or a network
            // failure warns and lets the rest of the bootstrap continue.
            try makeInstallSwiftlintScript(in: tempDir, body: "echo 'checksum mismatch' >&2\nexit 1")

            Bootstrap.installPinnedSwiftlint(repoRoot: tempDir)
        }
    }
}

// MARK: - Fixtures

private func makeDirectory(at root: URL, path: String) throws -> URL {
    let url = root.appendingPathComponent(path)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

@discardableResult
private func makeFile(at directory: URL, named name: String) throws -> URL {
    let url = directory.appendingPathComponent(name)
    try "".write(to: url, atomically: true, encoding: .utf8)
    return url
}

private func exists(_ url: URL) -> Bool {
    FileManager.default.fileExists(atPath: url.path)
}

/// Writes an executable stand-in for the repository's scripts/install-swiftlint.sh.
private func makeInstallSwiftlintScript(in repoRoot: URL, body: String) throws {
    let scripts = try makeDirectory(at: repoRoot, path: "scripts")
    let script = scripts.appendingPathComponent("install-swiftlint.sh")
    try "#!/bin/sh\n\(body)\n".write(to: script, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)
}
