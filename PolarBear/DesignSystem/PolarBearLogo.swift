//
//  PolarBearLogo.swift
//  PolarBear
//
//  The PolarBear mascot, rendered from the `BearLogo` asset (a high-resolution crop of
//  the app artwork) with smooth, continuous corners.
//

import SwiftUI

struct PolarBearLogo: View {
    var size = AppTheme.Metrics.brandLogo

    var body: some View {
        Image(.bearLogo)
            .resizable()
            .interpolation(.high)
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(.rect(cornerRadius: size * 0.26))
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                    .stroke(AppTheme.hairline, lineWidth: 0.5)
            }
            .accessibilityLabel("PolarBear")
    }
}

#Preview {
    PolarBearLogo(size: 84)
        .padding()
        .background(AppTheme.appBackground)
}
