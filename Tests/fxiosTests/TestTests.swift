// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import ArgumentParser
import Foundation
import Testing
@testable import fxios

@Suite("Test Command Tests", .serialized)
struct TestCommandTests {
    // MARK: - Command Configuration Tests

    @Test("Command has correct name")
    func commandName() {
        #expect(Test.configuration.commandName == "test")
    }

    @Test("Command has non-empty abstract")
    func commandHasAbstract() {
        let abstract = Test.configuration.abstract
        #expect(!abstract.isEmpty)
    }

    @Test("Command has discussion text")
    func commandHasDiscussion() {
        let discussion = Test.configuration.discussion
        #expect(!discussion.isEmpty)
        #expect(discussion.contains("unit"))
        #expect(discussion.contains("smoke"))
    }

    // MARK: - TestPlan Enum Tests

    @Test("TestPlan enum has unit case")
    func planHasUnit() {
        let plan = TestPlan(rawValue: "unit")
        #expect(plan == .unit)
    }

    @Test("TestPlan enum has smoke case")
    func planHasSmoke() {
        let plan = TestPlan(rawValue: "smoke")
        #expect(plan == .smoke)
    }

    @Test("TestPlan enum has accessibility case")
    func planHasAccessibility() {
        let plan = TestPlan(rawValue: "accessibility")
        #expect(plan == .accessibility)
    }

    @Test("TestPlan enum has performance case")
    func planHasPerformance() {
        let plan = TestPlan(rawValue: "performance")
        #expect(plan == .performance)
    }

    @Test("TestPlan enum has full case")
    func planHasFull() {
        let plan = TestPlan(rawValue: "full")
        #expect(plan == .full)
    }

    @Test("TestPlan enum has exactly five cases")
    func planCaseCount() {
        #expect(TestPlan.allCases.count == 5)
    }

    @Test("TestPlan a11y shorthand parses to accessibility")
    func planA11yShorthand() {
        let plan = TestPlan(argument: "a11y")
        #expect(plan == .accessibility)
    }

    @Test("TestPlan perf shorthand parses to performance")
    func planPerfShorthand() {
        let plan = TestPlan(argument: "perf")
        #expect(plan == .performance)
    }

    @Test("TestPlan shorthands are case-insensitive")
    func planShorthandsCaseInsensitive() {
        #expect(TestPlan(argument: "A11Y") == .accessibility)
        #expect(TestPlan(argument: "PERF") == .performance)
        #expect(TestPlan(argument: "Unit") == .unit)
    }

    // MARK: - TestPlan xctestrun Prefix Tests

    @Test("Unit test plan prefix for Firefox")
    func unitPrefixFirefox() {
        #expect(TestPlan.unit.xctestrunPrefix(for: .firefox) == "Fennec_UnitTest")
    }

    @Test("Unit test plan prefix for Focus")
    func unitPrefixFocus() {
        #expect(TestPlan.unit.xctestrunPrefix(for: .focus) == "Focus_UnitTests")
    }

    @Test("Unit test plan prefix for Klar")
    func unitPrefixKlar() {
        #expect(TestPlan.unit.xctestrunPrefix(for: .klar) == "Klar_UnitTests")
    }

    @Test("Smoke test plan prefix for Firefox")
    func smokePrefixFirefox() {
        #expect(TestPlan.smoke.xctestrunPrefix(for: .firefox) == "Fennec_Smoketest")
    }

    @Test("Smoke test plan prefix for Focus")
    func smokePrefixFocus() {
        #expect(TestPlan.smoke.xctestrunPrefix(for: .focus) == "Focus_SmokeTest")
    }

    @Test("Accessibility test plan not available for Focus")
    func accessibilityNotAvailableForFocus() {
        #expect(TestPlan.accessibility.xctestrunPrefix(for: .focus) == nil)
    }

    @Test("Performance test plan not available for Focus")
    func performanceNotAvailableForFocus() {
        #expect(TestPlan.performance.xctestrunPrefix(for: .focus) == nil)
    }

    @Test("Full test plan not available for Firefox")
    func fullNotAvailableForFirefox() {
        #expect(TestPlan.full.xctestrunPrefix(for: .firefox) == nil)
    }

    @Test("Full test plan available for Focus")
    func fullAvailableForFocus() {
        #expect(TestPlan.full.xctestrunPrefix(for: .focus) == "Focus_FullFunctionalTests")
    }

    // MARK: - TestPlan Test Plan Name Tests

    @Test("Unit test plan name for Firefox")
    func unitNameFirefox() {
        #expect(TestPlan.unit.testPlanName(for: .firefox) == "UnitTest")
    }

    @Test("Smoke test plan name for Firefox")
    func smokeNameFirefox() {
        #expect(TestPlan.smoke.testPlanName(for: .firefox) == "Smoketest")
    }

    @Test("Accessibility test plan name for Firefox")
    func accessibilityNameFirefox() {
        #expect(TestPlan.accessibility.testPlanName(for: .firefox) == "AccessibilityTestPlan")
    }

    // MARK: - TestPlan Display Name Tests

    @Test("Unit test plan display name")
    func unitDisplayName() {
        #expect(TestPlan.unit.displayName == "Unit Tests")
    }

    @Test("Smoke test plan display name")
    func smokeDisplayName() {
        #expect(TestPlan.smoke.displayName == "Smoke Tests")
    }

    // MARK: - Argument Parsing Tests

    @Test("Can parse product option short form")
    func parseProductShort() throws {
        let command = try Test.parse(["-p", "focus"])
        #expect(command.product == .focus)
    }

    @Test("Can parse product option long form")
    func parseProductLong() throws {
        let command = try Test.parse(["--product", "klar"])
        #expect(command.product == .klar)
    }

    @Test("Can parse plan option")
    func parsePlan() throws {
        let command = try Test.parse(["--plan", "smoke"])
        #expect(command.plan == .smoke)
    }

    @Test("Can parse plan option with a11y shorthand")
    func parsePlanA11y() throws {
        let command = try Test.parse(["--plan", "a11y"])
        #expect(command.plan == .accessibility)
    }

    @Test("Can parse plan option with perf shorthand")
    func parsePlanPerf() throws {
        let command = try Test.parse(["--plan", "perf"])
        #expect(command.plan == .performance)
    }

    @Test("Can parse filter option")
    func parseFilter() throws {
        let command = try Test.parse(["--filter", "MyTestClass"])
        #expect(command.filter == "MyTestClass")
    }

    @Test("Can parse sim option")
    func parseSim() throws {
        let command = try Test.parse(["--sim", "17pro"])
        #expect(command.sim == "17pro")
    }

    @Test("Can parse os option")
    func parseOs() throws {
        let command = try Test.parse(["--os", "18.2"])
        #expect(command.os == "18.2")
    }

    @Test("Can parse build-first flag")
    func parseBuildFirst() throws {
        let command = try Test.parse(["--build-first"])
        #expect(command.buildFirst == true)
    }

    @Test("Can parse derived-data option")
    func parseDerivedData() throws {
        let command = try Test.parse(["--derived-data", "/tmp/DD"])
        #expect(command.derivedData == "/tmp/DD")
    }

    @Test("Can parse doNotSkipMacroValidation flag")
    func parseDoNotSkipMacroValidation() throws {
        let command = try Test.parse(["--doNotSkipMacroValidation"])
        #expect(command.doNotSkipMacroValidation == true)
        #expect(command.skipMacroValidation == false)
    }

    @Test("Can parse retries option")
    func parseRetries() throws {
        let command = try Test.parse(["--retries", "3"])
        #expect(command.retries == 3)
    }

    @Test("Can parse quiet flag short form")
    func parseQuietShort() throws {
        let command = try Test.parse(["-q"])
        #expect(command.quiet == true)
    }

    @Test("Can parse quiet flag long form")
    func parseQuietLong() throws {
        let command = try Test.parse(["--quiet"])
        #expect(command.quiet == true)
    }

    @Test("Can parse expose flag")
    func parseExpose() throws {
        let command = try Test.parse(["--expose"])
        #expect(command.expose == true)
    }

    @Test("Default values are correct")
    func defaultValues() throws {
        let command = try Test.parse([])
        #expect(command.product == nil)
        #expect(command.plan == .unit)
        #expect(command.filter == nil)
        #expect(command.sim == nil)
        #expect(command.os == nil)
        #expect(command.buildFirst == false)
        #expect(command.derivedData == nil)
        #expect(command.doNotSkipMacroValidation == false)
        #expect(command.skipMacroValidation == true)
        #expect(command.retries == 0)
        #expect(command.quiet == false)
        #expect(command.expose == false)
    }

    @Test("Can combine multiple options")
    func combineOptions() throws {
        let command = try Test.parse(["-p", "focus", "--plan", "smoke", "--build-first", "-q"])
        #expect(command.product == .focus)
        #expect(command.plan == .smoke)
        #expect(command.buildFirst == true)
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

        var command = try Test.parse([])
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

        var command = try Test.parse([])
        #expect(throws: RepoDetectorError.self) {
            try command.run()
        }
    }

    // MARK: - Error Description Tests

    @Test("TestError descriptions contain relevant info")
    func errorDescriptions() {
        let notAvailable = TestError.testPlanNotAvailable(plan: .accessibility, product: .focus)
        #expect(notAvailable.description.contains("accessibility"))
        #expect(notAvailable.description.contains("Focus"))

        let bundleNotFound = TestError.testBundleNotFound(path: "/some/path")
        #expect(bundleNotFound.description.contains("/some/path"))

        let xctestrunNotFound = TestError.xctestrunNotFound(pattern: "Fennec_*")
        #expect(xctestrunNotFound.description.contains("Fennec_*"))

        let testsFailed = TestError.testsFailed(exitCode: 65)
        #expect(testsFailed.description.contains("65"))
    }
}
