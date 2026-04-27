// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import ArgumentParser
import Foundation

/// Handles modifications to NimbusFlaggableFeature.swift
enum NimbusFlaggableFeatureEditor {
    struct RemovalResult {
        let enumCaseRemoved: Bool
        let debugKeyRemoved: Bool?  // nil = wasn't present, true = removed, false = failed to remove
        let userPrefsKeyRemoved: Bool?  // nil = wasn't present, true = removed, false = failed to remove
    }

    static func addFeature(
        name: String,
        debug: Bool,
        userToggleable: Bool,
        filePath: URL
    ) throws {
        var content = try String(contentsOf: filePath, encoding: .utf8)

        // 1. Add enum case to NimbusFeatureFlagID
        content = try addEnumCase(name: name, to: content)

        // 2. Add to debugKey if --debuggable
        if debug {
            content = try addToDebugKey(name: name, to: content)
        }

        // 3. Add to userPrefsKey if user-toggleable
        if userToggleable {
            content = try addToUserPrefsKey(name: name, to: content)
        }

        try content.write(to: filePath, atomically: true, encoding: .utf8)
    }

    static func removeFeature(name: String, filePath: URL) throws -> RemovalResult {
        var content = try String(contentsOf: filePath, encoding: .utf8)
        let originalContent = content

        // 1. Remove enum case
        let (contentAfterEnum, enumRemoved) = removeEnumCase(name: name, from: content)
        content = contentAfterEnum

        // 2. Check if in debugKey and try to remove
        let wasInDebugKey = isInDebugKey(name: name, content: originalContent)
        var debugKeyRemoved: Bool?
        if wasInDebugKey {
            let (contentAfterDebug, removed) = removeFromDebugKey(name: name, from: content)
            content = contentAfterDebug
            debugKeyRemoved = removed
        }

        // 3. Check if in userPrefsKey and try to remove
        let wasInUserPrefsKey = isInUserPrefsKey(name: name, content: originalContent)
        var userPrefsKeyRemoved: Bool?
        if wasInUserPrefsKey {
            let (contentAfterPrefs, removed) = removeFromUserPrefsKey(name: name, from: content)
            content = contentAfterPrefs
            userPrefsKeyRemoved = removed
        }

        try content.write(to: filePath, atomically: true, encoding: .utf8)

        return RemovalResult(
            enumCaseRemoved: enumRemoved,
            debugKeyRemoved: debugKeyRemoved,
            userPrefsKeyRemoved: userPrefsKeyRemoved
        )
    }

    // MARK: - Detection Helpers

    private static func isInDebugKey(name: String, content: String) -> Bool {
        let debugKeyPattern = "\\.\(name)[,:]"
        return content.range(of: debugKeyPattern, options: .regularExpression) != nil &&
            content.contains("var debugKey: String?")
    }

    private static func isInUserPrefsKey(name: String, content: String) -> Bool {
        let lines = content.components(separatedBy: "\n")
        var inUserPrefsKey = false
        for line in lines {
            if line.contains("var userPrefsKey: String?") {
                inUserPrefsKey = true
                continue
            }
            if inUserPrefsKey {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed == "default:" || trimmed == "}" {
                    break
                }
                if trimmed.hasPrefix("case .\(name):") {
                    return true
                }
            }
        }
        return false
    }

    // MARK: - Enum Case Operations

    private static func addEnumCase(name: String, to content: String) throws -> String {
        var lines = content.components(separatedBy: "\n")

        // Find the enum and insert alphabetically
        var inEnum = false
        var insertIndex: Int?
        var lastCaseIndex: Int?

        for (index, line) in lines.enumerated() {
            if line.contains("enum FeatureFlagID") {
                inEnum = true
                continue
            }

            if inEnum {
                if line.trimmingCharacters(in: .whitespaces).hasPrefix("case ") {
                    let caseName = extractCaseName(from: line)
                    lastCaseIndex = index

                    if caseName > name && insertIndex == nil {
                        insertIndex = index
                    }
                }

                // End of enum cases (next section or closing brace)
                if line.trimmingCharacters(in: .whitespaces).hasPrefix("//") ||
                   line.trimmingCharacters(in: .whitespaces).hasPrefix("var ") ||
                   line.trimmingCharacters(in: .whitespaces) == "}" {
                    if insertIndex == nil {
                        insertIndex = lastCaseIndex.map { $0 + 1 }
                    }
                    break
                }
            }
        }

        guard let index = insertIndex else {
            throw ValidationError("Could not find insertion point for enum case")
        }

        lines.insert("    case \(name)", at: index)
        return lines.joined(separator: "\n")
    }

    private static func removeEnumCase(name: String, from content: String) -> (String, Bool) {
        var lines = content.components(separatedBy: "\n")

        if let index = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "case \(name)" }) {
            lines.remove(at: index)
            return (lines.joined(separator: "\n"), true)
        }

        return (content, false)
    }

    private static func extractCaseName(from line: String) -> String {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("case ") else { return "" }
        let afterCase = trimmed.dropFirst(5)
        return String(afterCase.prefix(while: { $0.isLetter || $0.isNumber }))
    }

    // MARK: - debugKey Operations

    private static func addToDebugKey(name: String, to content: String) throws -> String {
        var lines = content.components(separatedBy: "\n")

        // Find the debugKey var and the case list
        var inDebugKey = false
        var insertIndex: Int?

        for (index, line) in lines.enumerated() {
            if line.contains("var debugKey: String?") {
                inDebugKey = true
                continue
            }

            if inDebugKey {
                let trimmed = line.trimmingCharacters(in: .whitespaces)

                // Look for case entries like .featureName, or .featureName:
                if trimmed.hasPrefix(".") {
                    let featureName = String(trimmed.dropFirst().prefix(while: { $0.isLetter || $0.isNumber }))

                    if featureName > name && insertIndex == nil {
                        insertIndex = index
                    }
                }

                // End of the case list (return statement)
                if trimmed.hasPrefix("return rawValue") {
                    if insertIndex == nil {
                        // Insert before the last feature (which has : instead of ,)
                        insertIndex = index - 1
                        // Find the last .feature line
                        for i in stride(from: index - 1, through: 0, by: -1) {
                            let prevLine = lines[i].trimmingCharacters(in: .whitespaces)
                            if prevLine.hasPrefix(".") {
                                // Change the : to , and insert after
                                if prevLine.hasSuffix(":") {
                                    lines[i] = lines[i].replacingOccurrences(of: ":", with: ",")
                                    insertIndex = i + 1
                                }
                                break
                            }
                        }
                    }
                    break
                }

                if trimmed == "default:" {
                    break
                }
            }
        }

        guard let index = insertIndex else {
            throw ValidationError("Could not find insertion point for debugKey")
        }

        // Determine if this is the last entry (should end with :) or not (should end with ,)
        let nextLine = lines[index].trimmingCharacters(in: .whitespaces)
        let suffix = nextLine.hasPrefix("return") ? ":" : ","

        lines.insert("                .\(name)\(suffix)", at: index)

        // If we inserted before a line that had :, change it to ,
        if suffix == ":" {
            let nextIdx = index + 1
            if nextIdx < lines.count && lines[nextIdx].hasSuffix(":") {
                lines[nextIdx] = lines[nextIdx].replacingOccurrences(of: ":", with: ",")
            }
        }

        return lines.joined(separator: "\n")
    }

    private static func removeFromDebugKey(name: String, from content: String) -> (String, Bool) {
        var lines = content.components(separatedBy: "\n")

        // Find and remove the .featureName line from debugKey section
        var inDebugKey = false

        for (index, line) in lines.enumerated() {
            if line.contains("var debugKey: String?") {
                inDebugKey = true
                continue
            }

            if inDebugKey {
                let trimmed = line.trimmingCharacters(in: .whitespaces)

                if trimmed == ".\(name)," || trimmed == ".\(name):" {
                    // If this was the last entry (ends with :), make the previous entry end with :
                    if trimmed.hasSuffix(":") {
                        for i in stride(from: index - 1, through: 0, by: -1) {
                            let prevLine = lines[i].trimmingCharacters(in: .whitespaces)
                            if prevLine.hasPrefix(".") && prevLine.hasSuffix(",") {
                                lines[i] = lines[i].replacingOccurrences(of: ",", with: ":")
                                break
                            }
                        }
                    }
                    lines.remove(at: index)
                    return (lines.joined(separator: "\n"), true)
                }

                if trimmed == "default:" {
                    break
                }
            }
        }

        return (content, false)
    }

    // MARK: - userPrefsKey Operations

    private static func addToUserPrefsKey(name: String, to content: String) throws -> String {
        var lines = content.components(separatedBy: "\n")

        var inUserPrefsKey = false
        var insertIndex: Int?
        var lastCaseIndex: Int?

        for (index, line) in lines.enumerated() {
            if line.contains("var userPrefsKey: String?") {
                inUserPrefsKey = true
                continue
            }

            if inUserPrefsKey {
                let trimmed = line.trimmingCharacters(in: .whitespaces)

                if trimmed.hasPrefix("case .") {
                    let caseName = String(trimmed.dropFirst(6).prefix(while: { $0.isLetter || $0.isNumber }))
                    lastCaseIndex = index

                    if caseName > name && insertIndex == nil {
                        insertIndex = index
                    }
                }

                if trimmed == "default:" {
                    if insertIndex == nil {
                        insertIndex = lastCaseIndex.map { $0 + 1 } ?? index
                    }
                    break
                }
            }
        }

        guard let index = insertIndex else {
            throw ValidationError("Could not find insertion point in userPrefsKey")
        }

        let newCase = "        case .\(name): fatalError(\"Please implement a preference key for this feature\")"
        lines.insert(newCase, at: index)

        return lines.joined(separator: "\n")
    }

    private static func removeFromUserPrefsKey(name: String, from content: String) -> (String, Bool) {
        var lines = content.components(separatedBy: "\n")

        var inUserPrefsKey = false

        for (index, line) in lines.enumerated() {
            if line.contains("var userPrefsKey: String?") {
                inUserPrefsKey = true
                continue
            }

            if inUserPrefsKey {
                let trimmed = line.trimmingCharacters(in: .whitespaces)

                if trimmed.hasPrefix("case .\(name):") {
                    lines.remove(at: index)
                    return (lines.joined(separator: "\n"), true)
                }

                if trimmed == "default:" || trimmed == "}" {
                    break
                }
            }
        }

        return (content, false)
    }
}
