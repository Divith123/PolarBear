//
//  SendButtonStyle.swift
//  PolarBear
//

import SwiftUI

/// The round white "send" button of the composer.
struct SendButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .labelStyle(.iconOnly)
            .font(.title3.bold())
            .foregroundStyle(AppTheme.onAccent)
            .frame(width: AppTheme.Metrics.floatingBarHeight - AppTheme.Spacing.m, height: AppTheme.Metrics.floatingBarHeight - AppTheme.Spacing.m)
            .background(AppTheme.accentInk, in: .circle)
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

extension ButtonStyle where Self == SendButtonStyle {
    static var send: SendButtonStyle { SendButtonStyle() }
}
