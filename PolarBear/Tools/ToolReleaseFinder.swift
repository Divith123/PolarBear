//
//  ToolReleaseFinder.swift
//  PolarBear
//

import Foundation

/// Asks GitHub which release of a tool to install: the newest stable one with a file for this Mac.
nonisolated enum ToolReleaseFinder {
    private struct Release: Decodable {
        struct Asset: Decodable {
            var name: String
            var browser_download_url: URL
            var digest: String?
        }

        var tag_name: String
        var draft: Bool
        var prerelease: Bool
        var assets: [Asset]
    }

    @concurrent
    static func latest(for tool: ManagedTool) async throws -> ToolRelease {
        var request = URLRequest(url: URL(string: "https://api.github.com/repos/\(tool.repository)/releases?per_page=40")!)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("PolarBear", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 20

        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieAcceptPolicy = .never
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession(configuration: configuration).data(for: request)
        } catch {
            throw ToolInstallError.offline(error.localizedDescription)
        }
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw ToolInstallError.offline("HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
        }
        let releases = try JSONDecoder().decode([Release].self, from: data)

        var best: (version: String, release: Release, asset: Release.Asset)?
        for release in releases where !release.draft && !release.prerelease {
            guard let version = tool.version(fromTag: release.tag_name), tool.isSupported(version: version),
                  let asset = release.assets.first(where: { tool.isAsset(named: $0.name) })
            else { continue }
            if best == nil || isNewer(version, than: best!.version) { best = (version, release, asset) }
        }
        guard let best else { throw ToolInstallError.noRelease(tool) }

        guard let digest = best.asset.digest, digest.hasPrefix("sha256:") else {
            throw ToolInstallError.noChecksum(best.asset.name)
        }
        return ToolRelease(
            version: best.version,
            assetName: best.asset.name,
            downloadURL: best.asset.browser_download_url,
            sha256: String(digest.dropFirst("sha256:".count)).lowercased()
        )
    }

    private static func isNewer(_ lhs: String, than rhs: String) -> Bool {
        lhs.compare(rhs, options: .numeric) == .orderedDescending
    }
}
