//
//  PolarBearEngineNote.swift
//  PolarBear
//

import SwiftUI

/// Says plainly whether the PolarBear Engine can compile documents yet.
struct PolarBearEngineNote: View {
    let isBuilt: Bool
    let typesets: Bool
    var version: String?
    var isBundled = false

    var body: some View {
        Group {
            if typesets {
                Text("Version \(versionText), \(whereText). Ready: “Automatic” compiles with the PolarBear Engine.")
            } else if isBuilt {
                Text("Version \(versionText), \(whereText). It is connected and checked at every launch, but its typesetting core is not finished yet. Until it is, “Automatic” compiles with Tectonic, and choosing the PolarBear Engine by hand fails with “typesetting core pending”. It takes over by itself as soon as it can typeset.")
            } else {
                Text("Not found. Run Scripts/build_release.sh to build the app with the engine inside it, then choose Check Again.")
            }
        }
        .foregroundStyle(.secondary)
        .font(.callout)
    }

    private var versionText: String {
        version ?? "unknown"
    }

    private var whereText: String {
        isBundled ? String(localized: "built into the app") : String(localized: "development build")
    }
}
