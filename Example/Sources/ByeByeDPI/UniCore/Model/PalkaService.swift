//
//  PalkaService.swift
//  PalkaDPI
//

import Foundation

struct PalkaService: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let icon: String
    let probeURL: URL
    let expectedResponseMarker: String?
    let domains: [String]

    static let all: [PalkaService] = [
        PalkaService(
            id: "discord",
            name: "Discord",
            icon: "bubble.left.and.bubble.right.fill",
            probeURL: URL(string: "https://discord.com/api/v10/gateway")!,
            expectedResponseMarker: "gateway.discord.gg",
            domains: [
                "dis.gd", "discord-activities.com", "discord.app", "discord.co",
                "discord.com", "discord.design", "discord.dev", "discord.gg",
                "discord.gift", "discord.gifts", "discord.media", "discord.new",
                "discord.store", "discord.tools", "discordactivities.com",
                "discordapp.com", "discordapp.net", "discordcdn.com",
                "discordmerch.com", "discordpartygames.com", "discordsays.com",
                "discordsez.com",
            ]
        ),
        PalkaService(
            id: "youtube",
            name: "YouTube",
            icon: "play.rectangle.fill",
            probeURL: URL(string: "https://www.youtube.com/robots.txt")!,
            expectedResponseMarker: "robots.txt file for YouTube",
            domains: [
                "ggpht.com", "googleapis.com", "googleusercontent.com",
                "googlevideo.com", "returnyoutubedislikeapi.com", "youtu.be",
                "youtube-nocookie.com", "youtube.com", "youtubekids.com",
                "yt.be", "ytimg.com",
            ]
        ),
        PalkaService(
            id: "instagram",
            name: "Instagram",
            icon: "camera.fill",
            probeURL: URL(string: "https://www.instagram.com/robots.txt")!,
            expectedResponseMarker: "Instagram",
            domains: ["cdninstagram.com", "instagram.com", "instagram.net"]
        ),
        PalkaService(
            id: "tiktok",
            name: "TikTok",
            icon: "music.note",
            probeURL: URL(string: "https://www.tiktok.com/robots.txt")!,
            expectedResponseMarker: "User-agent:",
            domains: [
                "byteoversea.com", "ibytedtos.com", "ibyteimg.com", "muscdn.com",
                "musical.ly", "sgpstatp.com", "tiktok.com", "tiktokcdn.com",
                "tiktokcdn-us.com", "tiktokv.com",
            ]
        ),
        PalkaService(
            id: "x",
            name: "X / Twitter",
            icon: "at",
            probeURL: URL(string: "https://x.com/robots.txt")!,
            expectedResponseMarker: "Google / Bing Search Engine Robots",
            domains: ["t.co", "twimg.com", "twitter.com", "x.com"]
        ),
        PalkaService(
            id: "telegram",
            name: "Telegram",
            icon: "paperplane.fill",
            probeURL: URL(string: "https://telegram.org/")!,
            expectedResponseMarker: "Telegram Messenger",
            domains: ["t.me", "telegram.dog", "telegram.me", "telegram.org"]
        ),
    ]

    static let defaultIDs = ["discord", "youtube"]

    static func selected(from identifiers: [String]) -> [PalkaService] {
        let selected = Set(identifiers)
        let result = all.filter { selected.contains($0.id) }
        return result.isEmpty ? all.filter { defaultIDs.contains($0.id) } : result
    }

    static func targetsArgument(for identifiers: [String], customDomains: [String] = []) -> String {
        let builtInDomains = selected(from: identifiers)
            .flatMap(\.domains)
        let domains = (builtInDomains + sanitizedCustomDomains(customDomains))
            .reduce(into: [String]()) { result, domain in
                if !result.contains(domain) {
                    result.append(domain)
                }
            }
        return "-H:" + domains.joined(separator: " ")
    }

    static func sanitizedCustomDomains(_ domains: [String]) -> [String] {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-.")
        return Array(domains.compactMap { rawValue -> String? in
            var value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if let schemeRange = value.range(of: "://") {
                value = String(value[schemeRange.upperBound...])
            }
            value = String(value.split(separator: "/").first ?? "")
            value = value.trimmingCharacters(in: CharacterSet(charactersIn: "."))
            guard value.count >= 3,
                  value.count <= 253,
                  value.contains("."),
                  value.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
                return nil
            }
            return value
        }.prefix(100))
    }

    static func diagnosticTargets(serviceIDs: [String], customDomains: [String]) -> [PalkaService] {
        let custom = sanitizedCustomDomains(customDomains).compactMap { domain -> PalkaService? in
            guard let url = URL(string: "https://\(domain)/") else { return nil }
            return PalkaService(
                id: "custom:\(domain)",
                name: domain,
                icon: "globe",
                probeURL: url,
                expectedResponseMarker: nil,
                domains: [domain]
            )
        }
        return selected(from: serviceIDs) + custom
    }

    func validatesProbeResponse(data: Data, response: URLResponse?) -> Bool {
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode),
              let expectedHost = probeURL.host?.lowercased(),
              let finalHost = httpResponse.url?.host?.lowercased(),
              finalHost == expectedHost || finalHost.hasSuffix("." + expectedHost) else {
            return false
        }
        guard let marker = expectedResponseMarker else { return true }
        return String(data: data, encoding: .utf8)?.localizedCaseInsensitiveContains(marker) == true
    }
}

enum PalkaNetworkKind: String, Codable, CaseIterable, Identifiable {
    case wifi
    case cellular
    case wired
    case other
    case offline

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .wifi: return "wifi"
        case .cellular: return "antenna.radiowaves.left.and.right"
        case .wired: return "cable.connector"
        case .other: return "network"
        case .offline: return "wifi.slash"
        }
    }
}

struct PalkaNetworkProfile: Codable, Identifiable, Equatable {
    var id: String { networkKind.rawValue }
    let networkKind: PalkaNetworkKind
    var strategyID: String
    var strategyName: String
    var commandTemplate: [String]
}
