// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import ArgumentParser
import Foundation
import Testing
@testable import fxios

@Suite("Build Tests", .serialized)
struct BuildTests {
    // MARK: - Command Configuration Tests

    @Test("Command has correct name")
    func commandName() {
        #expect(Build.configuration.commandName == "build")
    }

    @Test("Command has non-empty abstract")
    func commandHasAbstract() {
        let abstract = Build.configuration.abstract
        #expect(!abstract.isEmpty)
    }

    @Test("Command has discussion text")
    func commandHasDiscussion() {
        let discussion = Build.configuration.discussion
        #expect(!discussion.isEmpty)
        #expect(discussion.contains("Firefox") || discussion.contains("product"))
    }

    // MARK: - BuildProduct Enum Tests

    @Test("BuildProduct enum has firefox case")
    func productHasFirefox() {
        let product = BuildProduct(rawValue: "firefox")
        #expect(product == .firefox)
    }

    @Test("BuildProduct enum has focus case")
    func productHasFocus() {
        let product = BuildProduct(rawValue: "focus")
        #expect(product == .focus)
    }

    @Test("BuildProduct enum has klar case")
    func productHasKlar() {
        let product = BuildProduct(rawValue: "klar")
        #expect(product == .klar)
    }

    @Test("BuildProduct enum raw values are correct")
    func productRawValues() {
        #expect(BuildProduct.firefox.rawValue == "firefox")
        #expect(BuildProduct.focus.rawValue == "focus")
        #expect(BuildProduct.klar.rawValue == "klar")
    }

    @Test("BuildProduct enum has exactly three cases")
    func productCaseCount() {
        #expect(BuildProduct.allCases.count == 3)
    }

    @Test("BuildProduct schemes are correct")
    func productSchemes() {
        #expect(BuildProduct.firefox.scheme == "Fennec")
        #expect(BuildProduct.focus.scheme == "Focus")
        #expect(BuildProduct.klar.scheme == "Klar")
    }

    @Test("BuildProduct project paths are correct")
    func productProjectPaths() {
        #expect(BuildProduct.firefox.projectPath == "firefox-ios/Client.xcodeproj")
        #expect(BuildProduct.focus.projectPath == "focus-ios/Blockzilla.xcodeproj")
        #expect(BuildProduct.klar.projectPath == "focus-ios/Blockzilla.xcodeproj")
    }

    @Test("BuildProduct default configurations are correct")
    func productDefaultConfigurations() {
        #expect(BuildProduct.firefox.defaultConfiguration == "Fennec")
        #expect(BuildProduct.focus.defaultConfiguration == "FocusDebug")
        #expect(BuildProduct.klar.defaultConfiguration == "KlarDebug")
    }

    @Test("BuildProduct testing configurations are correct")
    func productTestingConfigurations() {
        #expect(BuildProduct.firefox.testingConfiguration == "Fennec_Testing")
        #expect(BuildProduct.focus.testingConfiguration == "FocusDebug")
        #expect(BuildProduct.klar.testingConfiguration == "KlarDebug")
    }

    @Test("BuildProduct bundle identifiers are correct")
    func productBundleIdentifiers() {
        #expect(BuildProduct.firefox.bundleIdentifier == "org.mozilla.ios.Fennec")
        #expect(BuildProduct.focus.bundleIdentifier == "org.mozilla.ios.Focus")
        #expect(BuildProduct.klar.bundleIdentifier == "org.mozilla.ios.Klar")
    }

    // MARK: - Argument Parsing Tests

    @Test("Can parse product option short form")
    func parseProductShort() throws {
        let command = try Build.parse(["-p", "focus"])
        #expect(command.product == .focus)
    }

    @Test("Can parse product option long form")
    func parseProductLong() throws {
        let command = try Build.parse(["--product", "klar"])
        #expect(command.product == .klar)
    }

    @Test("Can parse for-testing flag")
    func parseForTesting() throws {
        let command = try Build.parse(["--for-testing"])
        #expect(command.forTesting == true)
    }

    @Test("Can parse device flag")
    func parseDevice() throws {
        let command = try Build.parse(["--device"])
        #expect(command.device == true)
    }

    @Test("Can parse sim option")
    func parseSim() throws {
        let command = try Build.parse(["--sim", "17pro"])
        #expect(command.sim == "17pro")
    }

    @Test("Can parse os option")
    func parseOs() throws {
        let command = try Build.parse(["--os", "18.2"])
        #expect(command.os == "18.2")
    }

    @Test("Can parse configuration option")
    func parseConfiguration() throws {
        let command = try Build.parse(["--configuration", "Fennec_Testing"])
        #expect(command.configuration == "Fennec_Testing")
    }

    @Test("Can parse derived-data option")
    func parseDerivedData() throws {
        let command = try Build.parse(["--derived-data", "/tmp/DD"])
        #expect(command.derivedData == "/tmp/DD")
    }

    @Test("Can parse doNotSkipMacroValidation flag")
    func parseDoNotSkipMacroValidation() throws {
        let command = try Build.parse(["--doNotSkipMacroValidation"])
        #expect(command.doNotSkipMacroValidation == true)
        #expect(command.skipMacroValidation == false)
    }

    @Test("Can parse skip-resolve flag")
    func parseSkipResolve() throws {
        let command = try Build.parse(["--skip-resolve"])
        #expect(command.skipResolve == true)
    }

    @Test("Can parse clean flag")
    func parseClean() throws {
        let command = try Build.parse(["--clean"])
        #expect(command.clean == true)
    }

    @Test("Can parse quiet flag short form")
    func parseQuietShort() throws {
        let command = try Build.parse(["-q"])
        #expect(command.quiet == true)
    }

    @Test("Can parse quiet flag long form")
    func parseQuietLong() throws {
        let command = try Build.parse(["--quiet"])
        #expect(command.quiet == true)
    }

    @Test("Can parse expose flag")
    func parseExpose() throws {
        let command = try Build.parse(["--expose"])
        #expect(command.expose == true)
    }

    @Test("Default values are correct")
    func defaultValues() throws {
        let command = try Build.parse([])
        #expect(command.product == nil)
        #expect(command.forTesting == false)
        #expect(command.device == false)
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
        let command = try Build.parse(["-p", "focus", "--for-testing", "--clean", "-q"])
        #expect(command.product == .focus)
        #expect(command.forTesting == true)
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

        var command = try Build.parse([])
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

        var command = try Build.parse([])
        #expect(throws: RepoDetectorError.self) {
            try command.run()
        }
    }

    // MARK: - Config Tests

    @Test("Config with default_build_product is parsed correctly")
    func configWithDefaultBuildProduct() throws {
        let tempDir = try createTempDirectory()
        defer { cleanup(tempDir) }

        let markerPath = tempDir.appendingPathComponent(Configuration.markerFileName)
        let yaml = """
            project: firefox-ios
            default_build_product: focus
            """
        try yaml.write(to: markerPath, atomically: true, encoding: .utf8)

        let config = try RepoDetector.loadConfig(from: markerPath)
        #expect(config.defaultBuildProduct == "focus")
    }

    @Test("Config without default_build_product has nil value")
    func configWithoutDefaultBuildProduct() throws {
        let tempDir = try createTempDirectory()
        defer { cleanup(tempDir) }

        let markerPath = tempDir.appendingPathComponent(Configuration.markerFileName)
        try "project: firefox-ios".write(to: markerPath, atomically: true, encoding: .utf8)

        let config = try RepoDetector.loadConfig(from: markerPath)
        #expect(config.defaultBuildProduct == nil)
    }
}
