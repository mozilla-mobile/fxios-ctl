// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import ArgumentParser
import Foundation
import Testing
@testable import fxios

/// Tests for the L10nProduct enum and product-based configuration.
@Suite("L10nProduct Tests")
struct L10nProductTests {

    // MARK: - Enum Cases

    @Suite("Product Enum Cases")
    struct ProductEnumCasesTests {

        @Test("Product has firefox case")
        func hasFirefoxCase() {
            let product = L10nProduct.firefox
            #expect(product.rawValue == "firefox")
        }

        @Test("Product has focus case")
        func hasFocusCase() {
            let product = L10nProduct.focus
            #expect(product.rawValue == "focus")
        }

        @Test("Product has exactly two cases")
        func hasTwoCases() {
            #expect(L10nProduct.allCases.count == 2)
        }
    }

    // MARK: - Firefox Defaults

    @Suite("Firefox Product Defaults")
    struct FirefoxDefaultsTests {

        @Test("Firefox xliffName is firefox-ios.xliff")
        func firefoxXliffName() {
            #expect(L10nProduct.firefox.xliffName == "firefox-ios.xliff")
        }

        @Test("Firefox exportBasePath is /tmp/ios-localization")
        func firefoxExportBasePath() {
            #expect(L10nProduct.firefox.exportBasePath == "/tmp/ios-localization")
        }

        @Test("Firefox developmentRegion is en-US")
        func firefoxDevelopmentRegion() {
            #expect(L10nProduct.firefox.developmentRegion == "en-US")
        }

        @Test("Firefox projectName is Client.xcodeproj")
        func firefoxProjectName() {
            #expect(L10nProduct.firefox.projectName == "Client.xcodeproj")
        }

        @Test("Firefox projectPath is firefox-ios/Client.xcodeproj")
        func firefoxProjectPath() {
            #expect(L10nProduct.firefox.projectPath == "firefox-ios/Client.xcodeproj")
        }

        @Test("Firefox skipWidgetKit is false")
        func firefoxSkipWidgetKit() {
            #expect(L10nProduct.firefox.skipWidgetKit == false)
        }
    }

    // MARK: - Focus Defaults

    @Suite("Focus Product Defaults")
    struct FocusDefaultsTests {

        @Test("Focus xliffName is focus-ios.xliff")
        func focusXliffName() {
            #expect(L10nProduct.focus.xliffName == "focus-ios.xliff")
        }

        @Test("Focus exportBasePath is /tmp/ios-localization-focus")
        func focusExportBasePath() {
            #expect(L10nProduct.focus.exportBasePath == "/tmp/ios-localization-focus")
        }

        @Test("Focus developmentRegion is en")
        func focusDevelopmentRegion() {
            #expect(L10nProduct.focus.developmentRegion == "en")
        }

        @Test("Focus projectName is Blockzilla.xcodeproj")
        func focusProjectName() {
            #expect(L10nProduct.focus.projectName == "Blockzilla.xcodeproj")
        }

        @Test("Focus projectPath is focus-ios/Blockzilla.xcodeproj")
        func focusProjectPath() {
            #expect(L10nProduct.focus.projectPath == "focus-ios/Blockzilla.xcodeproj")
        }

        @Test("Focus skipWidgetKit is true")
        func focusSkipWidgetKit() {
            #expect(L10nProduct.focus.skipWidgetKit == true)
        }
    }

    // MARK: - BuildProduct Parity

    /// L10nProduct.projectPath must match BuildProduct.projectPath for the same product,
    /// since both resolve against the same repo root. Drift caused issue #23.
    @Suite("BuildProduct Parity")
    struct BuildProductParityTests {

        @Test("Firefox projectPath matches BuildProduct.firefox")
        func firefoxProjectPathMatchesBuildProduct() {
            #expect(L10nProduct.firefox.projectPath == BuildProduct.firefox.projectPath)
        }

        @Test("Focus projectPath matches BuildProduct.focus")
        func focusProjectPathMatchesBuildProduct() {
            #expect(L10nProduct.focus.projectPath == BuildProduct.focus.projectPath)
        }
    }

    // MARK: - Argument Parser Integration

    @Suite("ArgumentParser Integration")
    struct ArgumentParserIntegrationTests {

        @Test("Product can be parsed as argument")
        func productCanBeParsedAsArgument() throws {
            let command = try L10n.Export.parse([
                "--product", "firefox",
                "--l10n-project-path", "/test"
            ])
            #expect(command.product == .firefox)
        }

        @Test("Focus product can be parsed")
        func focusProductCanBeParsed() throws {
            let command = try L10n.Export.parse([
                "--product", "focus",
                "--l10n-project-path", "/test"
            ])
            #expect(command.product == .focus)
        }

        @Test("Import command parses product")
        func importParsesProduct() throws {
            let command = try L10n.Import.parse([
                "--product", "focus",
                "--l10n-project-path", "/test"
            ])
            #expect(command.product == .focus)
        }

        @Test("Templates command parses product")
        func templatesParsesProduct() throws {
            let command = try L10n.Templates.parse([
                "--product", "focus",
                "--l10n-project-path", "/test"
            ])
            #expect(command.product == .focus)
        }
    }

    // MARK: - Product or ProjectPath Required

    @Suite("Product or ProjectPath Required")
    struct ProductOrProjectPathRequiredTests {

        @Test("Export throws when both product and project-path specified")
        func exportThrowsForBothProductAndProjectPath() throws {
            // Validation happens automatically during parse(), which wraps ValidationError in CommandError
            #expect(throws: (any Error).self) {
                _ = try L10n.Export.parse([
                    "--product", "firefox",
                    "--project-path", "/test/path",
                    "--l10n-project-path", "/test"
                ])
            }
        }

        @Test("Import throws when both product and project-path specified")
        func importThrowsForBothProductAndProjectPath() throws {
            // Validation happens automatically during parse(), which wraps ValidationError in CommandError
            #expect(throws: (any Error).self) {
                _ = try L10n.Import.parse([
                    "--product", "firefox",
                    "--project-path", "/test/path",
                    "--l10n-project-path", "/test"
                ])
            }
        }

        @Test("Export throws when neither product nor project-path specified")
        func exportThrowsForNeitherProductNorProjectPath() throws {
            #expect(throws: (any Error).self) {
                _ = try L10n.Export.parse([
                    "--l10n-project-path", "/test"
                ])
            }
        }

        @Test("Import throws when neither product nor project-path specified")
        func importThrowsForNeitherProductNorProjectPath() throws {
            #expect(throws: (any Error).self) {
                _ = try L10n.Import.parse([
                    "--l10n-project-path", "/test"
                ])
            }
        }

        @Test("Export allows only product")
        func exportAllowsOnlyProduct() throws {
            // Should not throw - only product specified
            _ = try L10n.Export.parse([
                "--product", "firefox",
                "--l10n-project-path", "/test"
            ])
        }

        @Test("Export allows only project-path")
        func exportAllowsOnlyProjectPath() throws {
            // Should not throw - only project-path specified
            _ = try L10n.Export.parse([
                "--project-path", "/test/path",
                "--l10n-project-path", "/test"
            ])
        }

        @Test("Import allows only product")
        func importAllowsOnlyProduct() throws {
            // Should not throw - only product specified
            _ = try L10n.Import.parse([
                "--product", "firefox",
                "--l10n-project-path", "/test"
            ])
        }

        @Test("Import allows only project-path")
        func importAllowsOnlyProjectPath() throws {
            // Should not throw - only project-path specified
            _ = try L10n.Import.parse([
                "--project-path", "/test/path",
                "--l10n-project-path", "/test"
            ])
        }
    }
}
