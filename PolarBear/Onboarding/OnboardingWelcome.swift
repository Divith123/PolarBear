//
//  OnboardingWelcome.swift
//  PolarBear
//

import SwiftUI

/// First screen: the bear fills the window, with a solid card and the Next button.
struct OnboardingWelcome: View {
    let next: () -> Void

    var body: some View {
        Color.clear
            .overlay {
                Image(.polarBearArtwork)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
                    .accessibilityHidden(true)
            }
            .clipped()
            .overlay(alignment: .bottom) {
                VStack(spacing: AppTheme.Spacing.l) {
                    Text("Welcome to PolarBear")
                        .font(AppTheme.Typography.welcomeTitle)
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("LaTeX on your Mac. Your files, your engine, your agents.")
                        .font(AppTheme.Typography.welcomeSubtitle)
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                    OnboardingButton(title: "Next", isProminent: true, action: next)
                        .keyboardShortcut(.defaultAction)
                        .padding(.top, AppTheme.Spacing.m)
                }
                .padding(AppTheme.Spacing.xxl)
                .frame(maxWidth: AppTheme.Metrics.onboardingCardWidth)
                .background(AppTheme.appBackground, in: .rect(cornerRadius: AppTheme.Radius.artwork))
                .overlay {
                    RoundedRectangle(cornerRadius: AppTheme.Radius.artwork, style: .continuous)
                        .stroke(AppTheme.hairline, lineWidth: 1)
                }
                .padding(AppTheme.Spacing.xxl)
            }
    }
}
