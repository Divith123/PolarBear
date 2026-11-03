//
//  WorkspaceModel+Agent.swift
//  PolarBear
//

import Foundation

extension WorkspaceModel {
    /// What the "Fix with AI" buttons do for this project, given the installed agents.
    func fixWithAIAction(catalog: AgentCatalog) -> FixWithAIAction {
        let kind = catalog.effective(for: project)
        let executable = kind.flatMap { catalog.installed[$0] }
        let build = project.build
        let hasProblems = build.errorCount + build.warningCount > 0
        return FixWithAIAction(
            hasProblems: hasProblems,
            isAvailable: kind != nil && !project.agent.isRunning,
            unavailableReason: kind == nil
                ? String(localized: "Install an agent to use this.")
                : (project.agent.isRunning ? String(localized: "The assistant is busy.") : nil),
            perform: { [project] in
                guard let kind, let executable else { return }
                project.agent.fixBuildProblems(with: kind, executable: executable, options: catalog.options(for: kind))
            }
        )
    }
}
