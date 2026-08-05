// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Foundation

enum LintHelpers {
    /// Location of the installer firefox-ios uses to pin SwiftLint, relative to the repo root.
    static let installScriptPath = "scripts/install-swiftlint.sh"

    // MARK: - Resolving SwiftLint

    /// Returns the SwiftLint executable that `fxios lint` should run.
    ///
    /// firefox-ios pins a SwiftLint version in `.swiftlint-version` and installs it
    /// into a gitignored `.tools/`. The Xcode build phases, the pre-push hook and CI
    /// all lint with that binary, so preferring it here is what keeps `fxios lint`
    /// agreeing with them. Checkouts that predate the pin fall back to PATH.
    ///
    /// - Parameter repoRoot: The firefox-ios root, or nil when it could not be detected.
    /// - Throws: `LintError.swiftlintNotFound` when neither source yields a binary.
    static func resolveSwiftlint(repoRoot: URL?) throws -> String {
        if let repoRoot, hasInstallScript(repoRoot: repoRoot) {
            if let pinned = pinnedSwiftlintPath(repoRoot: repoRoot) {
                return pinned
            }

            Herald.declare(
                "Could not install the SwiftLint version pinned in .swiftlint-version. "
                    + "Falling back to PATH; results may not match CI.",
                asError: true
            )
        }

        guard (try? ShellRunner.runAndCapture("which", arguments: ["swiftlint"])) != nil else {
            throw LintError.swiftlintNotFound
        }

        return "swiftlint"
    }

    /// Whether this checkout carries the pinned-SwiftLint installer.
    static func hasInstallScript(repoRoot: URL) -> Bool {
        FileManager.default.fileExists(atPath: repoRoot.appendingPathComponent(installScriptPath).path)
    }

    /// Resolves the pinned SwiftLint binary, installing it if it is not there yet.
    ///
    /// The installer prints the binary path on stdout and everything else on stderr,
    /// which `runAndCapture` discards.
    ///
    /// - Returns: The path to the pinned binary, or nil if it could not be resolved.
    static func pinnedSwiftlintPath(repoRoot: URL) -> String? {
        let script = repoRoot.appendingPathComponent(installScriptPath).path

        // --path-only never downloads, so the already-installed case stays fast.
        let installed = try? ShellRunner.runAndCapture(
            script,
            arguments: ["--path-only"],
            workingDirectory: repoRoot
        )

        if let path = lastNonEmptyLine(of: installed) {
            return path
        }

        Herald.declare("Installing the SwiftLint version pinned in .swiftlint-version...")

        let output = try? ShellRunner.runAndCapture(script, workingDirectory: repoRoot)
        return lastNonEmptyLine(of: output)
    }

    private static func lastNonEmptyLine(of output: String?) -> String? {
        output?
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .last { !$0.isEmpty }
    }

    // MARK: - Building Invocations

    /// Builds a `swiftlint lint` invocation.
    ///
    /// Deliberately passes no `--config`. firefox-ios relies on nested configuration:
    /// there are `.swiftlint.yml` files under `focus-ios` and `BrowserKit/Tests`
    /// alongside the root one, and SwiftLint only applies them when it is left to
    /// discover configs itself. Both the Xcode build phases and the CI lint step run
    /// from the repo root without a config for exactly this reason.
    ///
    /// Files are passed positionally in a single invocation, matching the build phases.
    static func lintArguments(fix: Bool = false, flags: [String] = [], files: [String] = []) -> [String] {
        var arguments = ["lint"]
        if fix { arguments.append("--fix") }
        arguments.append(contentsOf: flags)
        arguments.append(contentsOf: files)
        return arguments
    }

    // MARK: - Changed Files

    static func getChangedSwiftFiles(repoRoot: URL) throws -> [String] {
        let mergeBase = try ShellRunner.runAndCapture(
            "git",
            arguments: ["merge-base", "HEAD", "main"],
            workingDirectory: repoRoot
        ).trimmingCharacters(in: .whitespacesAndNewlines)

        let output = try ShellRunner.runAndCapture(
            "git",
            arguments: ["diff", "--name-only", "--diff-filter=ACMR", "\(mergeBase)...HEAD"],
            workingDirectory: repoRoot
        )

        let fileManager = FileManager.default
        let files = output
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && $0.hasSuffix(".swift") }
            .map { repoRoot.appendingPathComponent($0).path }
            .filter { fileManager.fileExists(atPath: $0) }

        return files
    }
}
