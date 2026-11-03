//
//  RemoteImagesToggle.swift
//  PolarBear
//

import SwiftUI

/// "Load Web Images": whether a Markdown document's `https` images are downloaded for the preview.
struct RemoteImagesToggle: View {
    @Bindable var project: Project

    var body: some View {
        if project.settings.mode == .markdown {
            Toggle("Load Web Images", isOn: $project.settings.loadsRemoteImages)
                .onChange(of: project.settings.loadsRemoteImages) {
                    project.compile()
                }
        }
    }
}
