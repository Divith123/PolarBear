//
//  OnboardingView.swift
//  PolarBear
//

import SwiftUI

/// Shown instead of the workspace until a profile exists: the bear with a Next button, then
/// the name and picture.
struct OnboardingView: View {
    @Environment(ProjectLibrary.self) private var library
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step = OnboardingStep.welcome
    @State private var draft = ProfileDraft()

    var body: some View {
        ZStack {
            switch step {
            case .welcome:
                OnboardingWelcome(next: showProfile)
            case .profile:
                OnboardingProfile(draft: $draft, back: showWelcome, finish: finish)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.appBackground)
        .overlay(alignment: .top) {
            Color.clear
                .frame(height: AppTheme.Metrics.barHeight)
                .background { WindowDragArea() }
        }
    }

    private func showProfile() {
        withAnimation(reduceMotion ? nil : AppTheme.Timing.disclosure) { step = .profile }
    }

    private func showWelcome() {
        withAnimation(reduceMotion ? nil : AppTheme.Timing.disclosure) { step = .welcome }
    }

    private func finish() {
        library.profile.save(draft)
    }
}
