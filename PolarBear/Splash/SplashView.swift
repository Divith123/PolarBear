//
//  SplashView.swift
//  PolarBear
//

import SwiftUI

/// The small window shown for two seconds at launch, like other professional apps: the bear,
/// the name, the version and a thin progress line. When it ends the main window opens.
struct SplashView: View {
    @Environment(ProjectLibrary.self) private var library
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress = 0.0

    var body: some View {
        VStack(spacing: 0) {
            Image(.polarBearArtwork)
                .resizable()
                .interpolation(.high)
                .aspectRatio(16.0 / 9.0, contentMode: .fill)
                .frame(width: AppTheme.Metrics.splashWidth, height: AppTheme.Metrics.splashWidth * 9.0 / 16.0)
                .clipped()
                .accessibilityHidden(true)

            Rectangle()
                .fill(AppTheme.hairline)
                .frame(height: AppTheme.Metrics.splashProgressHeight)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(AppTheme.accentInk)
                        .frame(width: AppTheme.Metrics.splashWidth * progress)
                }

            HStack {
                Text("PolarBear")
                    .font(AppTheme.Typography.section)
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Text("Version \(version)")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .padding(.horizontal, AppTheme.Spacing.xxl)
            .frame(height: AppTheme.Metrics.splashBarHeight)
        }
        .frame(width: AppTheme.Metrics.splashWidth)
        .background(AppTheme.appBackground)
        .ignoresSafeArea()
        .appAppearance()
        .task {
            if reduceMotion {
                progress = 1
            } else {
                withAnimation(.linear(duration: 2)) { progress = 1 }
            }
            do {
                try await Task.sleep(for: AppTheme.Timing.splash)
            } catch {
                return
            }
            openWindow(id: "main")
            dismissWindow(id: "splash")
        }
        .onOpenURL { url in
            // A file opened from Finder at launch: the main window picks it up once it exists.
            library.pendingOpen = url
        }
    }

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }
}
