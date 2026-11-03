//
//  AgentModelMenu.swift
//  PolarBear
//

import SwiftUI

/// Choose the model an agent uses: the CLI's own default, one of the models it offers, or any
/// id typed by hand.
struct AgentModelMenu: View {
    let kind: AgentKind
    let catalog: AgentCatalog

    @State private var isEnteringCustom = false
    @State private var customModel = ""

    var body: some View {
        let chosen = catalog.options(for: kind).model
        let models = catalog.models(for: kind)

        Menu {
            Button {
                catalog.setModel(nil, for: kind)
            } label: {
                if chosen == nil {
                    Label("Default", systemImage: "checkmark")
                } else {
                    Text("Default")
                }
            }
            if !models.isEmpty {
                Divider()
                ForEach(models, id: \.self) { model in
                    Button {
                        catalog.setModel(model, for: kind)
                    } label: {
                        if chosen == model {
                            Label(model, systemImage: "checkmark")
                        } else {
                            Text(verbatim: model)
                        }
                    }
                }
            }
            Divider()
            Button("Other…") {
                customModel = chosen ?? ""
                isEnteringCustom = true
            }
        } label: {
            HStack(spacing: AppTheme.Spacing.m) {
                Text(verbatim: chosen ?? String(localized: "Default"))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 0)
                Image(systemName: "chevron.up.chevron.down")
                    .imageScale(.small)
                    .foregroundStyle(AppTheme.iconTertiary)
                    .accessibilityHidden(true)
            }
            .font(AppTheme.Typography.rowDetail)
            .foregroundStyle(AppTheme.textPrimary)
            .padding(.horizontal, AppTheme.Spacing.l)
            .frame(height: AppTheme.Metrics.controlHeight - AppTheme.Spacing.xs)
            .frame(maxWidth: .infinity)
            .background(AppTheme.controlFill, in: .rect(cornerRadius: AppTheme.Radius.row))
            .contentShape(.rect(cornerRadius: AppTheme.Radius.row))
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .accessibilityLabel("Model")
        .alert("Model", isPresented: $isEnteringCustom) {
            TextField("Model id", text: $customModel)
            Button("Use This Model") { catalog.setModel(customModel, for: kind) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Type the model id exactly as \(kind.displayName) expects it.")
        }
    }
}
