//
//  OutlineList.swift
//  PolarBear
//

import SwiftUI

struct OutlineList: View {
    let items: [OutlineItem]
    let reveal: (Int) -> Void

    var body: some View {
        if items.isEmpty {
            // A plain label rather than a ContentUnavailableView: the pane is only ~100 pt tall.
            Text("No headings")
                .font(AppTheme.Typography.rowDetail)
                .foregroundStyle(AppTheme.textTertiary)
                .padding(.leading, AppTheme.Spacing.xxl)
                .padding(.top, AppTheme.Spacing.s)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(items) { item in
                        OutlineRow(item: item, reveal: reveal)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }
}
