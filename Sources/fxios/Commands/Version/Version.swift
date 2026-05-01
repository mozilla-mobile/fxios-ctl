// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import ArgumentParser
import Foundation

struct Version: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Display or update the version number in the firefox-ios repository.",
        subcommands: [Show.self, Bump.self, SetVersion.self, Verify.self, ListFiles.self]
    )

    // MARK: - Constants

    static let versionFileName = "version.txt"

    static let filesToUpdate = [
        "firefox-ios/Client/Info.plist",
        "firefox-ios/CredentialProvider/Info.plist",
        "firefox-ios/WidgetKit/Info.plist",
        "bitrise.yml"
    ]

    static let extensionsDir = "firefox-ios/Extensions"

    // MARK: - Version Types

    struct ParsedVersion {
        let major: Int
        let minor: Int
        let patch: Int?
    }

    // MARK: - Shared Helper Methods

    static func readVersion(repoRoot: URL) throws -> String {
        let versionFile = repoRoot.appendingPathComponent(versionFileName)
        guard FileManager.default.fileExists(atPath: versionFile.path) else {
            throw ValidationError("version.txt not found at \(versionFile.path)")
        }

        return try String(contentsOf: versionFile, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func parseVersion(_ version: String) throws -> ParsedVersion {
        let components = version.split(separator: ".")
        guard components.count == 2 || components.count == 3,
              let major = Int(components[0]),
              let minor = Int(components[1]) else {
            throw ValidationError(
                "Invalid version format '\(version)'. Expected X.Y or X.Y.Z where X, Y, and Z are numbers."
            )
        }

        var patch: Int?
        if components.count == 3 {
            guard let patchValue = Int(components[2]) else {
                throw ValidationError(
                    "Invalid version format '\(version)'. Expected X.Y or X.Y.Z where X, Y, and Z are numbers."
                )
            }
            patch = patchValue
        }

        return ParsedVersion(major: major, minor: minor, patch: patch)
    }

    static func updateVersionInFiles(from currentVersion: String, to newVersion: String, repoRoot: URL) throws {
        // Update specific files
        for relativePath in filesToUpdate {
            let filePath = repoRoot.appendingPathComponent(relativePath)
            try updateVersionInFile(at: filePath, from: currentVersion, to: newVersion)
        }

        // Update extension Info.plist files
        let extensionsPath = repoRoot.appendingPathComponent(extensionsDir)
        if FileManager.default.fileExists(atPath: extensionsPath.path) {
            try updateExtensionInfoPlists(in: extensionsPath, from: currentVersion, to: newVersion)
        }

        // Write new version to version.txt
        let versionFile = repoRoot.appendingPathComponent(versionFileName)
        try (newVersion + "\n").write(to: versionFile, atomically: true, encoding: .utf8)
    }

    private static func updateVersionInFile(at url: URL, from currentVersion: String, to newVersion: String) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            Herald.declare("Warning: File not found, skipping: \(url.path)", asError: true)
            return
        }

        let content = try String(contentsOf: url, encoding: .utf8)
        let updatedContent = content.replacingOccurrences(of: currentVersion, with: newVersion)
        try updatedContent.write(to: url, atomically: true, encoding: .utf8)
    }

    private static func updateExtensionInfoPlists(
        in extensionsDir: URL,
        from currentVersion: String,
        to newVersion: String
    ) throws {
        let fileManager = FileManager.default
        let extensionDirs = try fileManager.contentsOfDirectory(
            at: extensionsDir,
            includingPropertiesForKeys: [.isDirectoryKey]
        )

        for extDir in extensionDirs {
            let resourceValues = try extDir.resourceValues(forKeys: [.isDirectoryKey])
            guard resourceValues.isDirectory == true else { continue }

            let extContents = try fileManager.contentsOfDirectory(at: extDir, includingPropertiesForKeys: nil)
            for file in extContents where file.lastPathComponent.hasSuffix("Info.plist") {
                try updateVersionInFile(at: file, from: currentVersion, to: newVersion)
            }
        }
    }
}
