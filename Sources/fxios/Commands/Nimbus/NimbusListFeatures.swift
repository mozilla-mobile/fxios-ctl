// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import ArgumentParser
import Foundation

extension Nimbus {
    struct ListFeatures: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "list-features",
            abstract: "List all Nimbus feature files."
        )

        mutating func run() throws {
            let repo = try RepoDetector.requireValidRepo()
            let featuresDir = repo.root.appendingPathComponent(NimbusConstants.nimbusFeaturesPath)

            Herald.declare("Listing Nimbus features...", isNewCommand: true)

            guard FileManager.default.fileExists(atPath: featuresDir.path) else {
                Herald.declare("No nimbus-features directory found.", asError: true, asConclusion: true)
                return
            }

            guard let enumerator = FileManager.default.enumerator(
                at: featuresDir,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else {
                Herald.declare("Could not read nimbus-features directory.", asError: true, asConclusion: true)
                return
            }

            var features: [String] = []
            let featuresDirPath = featuresDir.path + "/"
            while let url = enumerator.nextObject() as? URL {
                guard url.pathExtension == "yaml" else { continue }
                let relativePath = url.path.replacingOccurrences(of: featuresDirPath, with: "")
                let name = (relativePath as NSString).deletingPathExtension
                features.append(name)
            }

            features.sort()

            for feature in features {
                Herald.declare(feature)
            }
            Herald.declare("Found \(features.count) feature(s).", asConclusion: true)
        }
    }
}
