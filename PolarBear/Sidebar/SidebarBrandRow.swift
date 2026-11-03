//
//  SidebarBrandRow.swift
//  PolarBear
//

import SwiftUI

/// The brand mark on its own row below the window buttons, aligned with the content. A project
/// window adds the TeX / Markdown dropdown on the right.
struct SidebarBrandRow<Trailing: View>: View {
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: AppTheme.Spacing.m) {
            PolarBearLogo()
            BetaBadge()
            Spacer(minLength: AppTheme.Spacing.m)
            trailing
        }
        .frame(maxWidth: .infinity, minHeight: AppTheme.Metrics.brandLogo, alignment: .leading)
    }
}

extension SidebarBrandRow where Trailing == EmptyView {
    init() {
        self.init { EmptyView() }
    }
}
