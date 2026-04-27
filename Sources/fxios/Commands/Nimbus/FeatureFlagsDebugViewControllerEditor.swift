// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import ArgumentParser
import Foundation

/// Handles modifications to FeatureFlagsDebugViewController.swift
enum FeatureFlagsDebugViewControllerEditor {
    struct RemovalResult {
        let wasPresent: Bool
        let removed: Bool
    }

    static func addFeature(name: String, filePath: URL) throws {
        var content = try String(contentsOf: filePath, encoding: .utf8)

        let titleText = StringUtils.camelToTitleCase(name)

        // Find the children array and insert alphabetically by titleText
        var lines = content.components(separatedBy: "\n")
        var inChildren = false
        var insertIndex: Int?
        var lastSettingEndIndex: Int?

        for (index, line) in lines.enumerated() {
            if line.contains("children: [Setting]") {
                inChildren = true
                continue
            }

            if inChildren {
                // Look for FeatureFlagsBoolSetting blocks
                if line.contains("FeatureFlagsBoolSetting(") {
                    // Extract the titleText from the next few lines
                    for i in index..<min(index + 5, lines.count) where lines[i].contains("titleText:") {
                        if let titleRange = lines[i].range(of: "\"([^\"]+)\"", options: .regularExpression) {
                            let existingTitle = String(lines[i][titleRange]).replacingOccurrences(of: "\"", with: "")
                            if existingTitle > titleText && insertIndex == nil {
                                insertIndex = index
                            }
                        }
                        break
                    }
                }

                // Track end of each setting block
                if line.trimmingCharacters(in: .whitespaces) == "}," {
                    lastSettingEndIndex = index
                }

                // End of children array (before the conditional #if block or closing bracket)
                if line.contains("#if canImport") || line.trimmingCharacters(in: .whitespaces) == "]" {
                    if insertIndex == nil {
                        insertIndex = lastSettingEndIndex.map { $0 + 1 }
                    }
                    break
                }
            }
        }

        guard let index = insertIndex else {
            throw ValidationError("Could not find insertion point for debug setting")
        }

        let settingCode = """
                    FeatureFlagsBoolSetting(
                        with: .\(name),
                        titleText: format(string: "\(titleText)"),
                        statusText: format(string: "Toggle \(titleText)")
                    ) { [weak self] _ in
                        self?.reloadView()
                    },
        """
        lines.insert(settingCode, at: index)

        content = lines.joined(separator: "\n")
        try content.write(to: filePath, atomically: true, encoding: .utf8)
    }

    static func featureExists(name: String, filePath: URL) throws -> Bool {
        let content = try String(contentsOf: filePath, encoding: .utf8)
        return content.contains("with: .\(name),")
    }

    static func removeFeature(name: String, filePath: URL) throws -> RemovalResult {
        var content = try String(contentsOf: filePath, encoding: .utf8)

        // Check if present
        let wasPresent = content.contains("with: .\(name),")
        if !wasPresent {
            return RemovalResult(wasPresent: false, removed: false)
        }

        var lines = content.components(separatedBy: "\n")

        // Find the FeatureFlagsBoolSetting block for this feature
        var blockStart: Int?
        var blockEnd: Int?

        for (index, line) in lines.enumerated() where line.contains("with: .\(name),") {
            // Find the start of this block (FeatureFlagsBoolSetting line)
            for i in stride(from: index, through: max(0, index - 5), by: -1)
                where lines[i].contains("FeatureFlagsBoolSetting(") {
                blockStart = i
                break
            }

            // Find the end of this block (}, line)
            for i in index..<min(index + 10, lines.count)
                where lines[i].trimmingCharacters(in: .whitespaces) == "}," {
                blockEnd = i
                break
            }
            break
        }

        guard let start = blockStart, let end = blockEnd else {
            return RemovalResult(wasPresent: true, removed: false)
        }

        lines.removeSubrange(start...end)

        content = lines.joined(separator: "\n")
        try content.write(to: filePath, atomically: true, encoding: .utf8)

        return RemovalResult(wasPresent: true, removed: true)
    }
}
