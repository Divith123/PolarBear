//
//  OnboardingProfile.swift
//  PolarBear
//

import SwiftUI

/// Second screen: ask for a name and a picture.
struct OnboardingProfile: View {
    @Binding var draft: ProfileDraft
    let back: () -> Void
    let finish: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.xxl) {
                VStack(spacing: AppTheme.Spacing.s) {
                    Text("What should we call you?")
                        .font(AppTheme.Typography.welcomeTitle)
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Pick a name and a picture. They stay on this Mac.")
                        .font(AppTheme.Typography.welcomeSubtitle)
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }

                ProfileEditor(draft: $draft, focusesName: true)
                    .onSubmit(submit)

                HStack(spacing: AppTheme.Spacing.m) {
                    OnboardingButton(title: "Back", isProminent: false, action: back)
                    OnboardingButton(title: "Get Started", isProminent: true, action: submit)
                        .keyboardShortcut(.defaultAction)
                        .disabled(!draft.isValid)
                }
            }
            .frame(maxWidth: AppTheme.Metrics.onboardingCardWidth)
            .padding(AppTheme.Spacing.xxl)
            .padding(.top, AppTheme.Metrics.barHeight)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
    }

    private func submit() {
        if draft.isValid { finish() }
    }
}
