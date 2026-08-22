//
//  ServiceLatencyMonitor.swift
//  PalkaDPI
//

import Foundation
import SwiftUI

enum PalkaServiceProbeStatus {
    case idle
    case testing
    case reachable
    case unavailable
}

struct PalkaServiceProbe: Identifiable {
    let id: String
    let name: String
    fileprivate let url: URL
    var status: PalkaServiceProbeStatus
    var latencyMilliseconds: Int?
}

final class ServiceLatencyMonitor: ObservableObject {
    @Published private(set) var services: [PalkaServiceProbe] = [
        PalkaServiceProbe(
            id: "discord",
            name: "Discord",
            url: URL(string: "https://discord.com/api/v10/gateway")!,
            status: .idle,
            latencyMilliseconds: nil
        ),
        PalkaServiceProbe(
            id: "youtube",
            name: "YouTube",
            url: URL(string: "https://www.youtube.com/robots.txt")!,
            status: .idle,
            latencyMilliseconds: nil
        ),
    ]

    @Published private(set) var isRefreshing = false

    private var currentGeneration = UUID()
    private var tasks: [URLSessionDataTask] = []

    deinit {
        tasks.forEach { $0.cancel() }
    }

    func refresh() {
        tasks.forEach { $0.cancel() }
        tasks.removeAll()

        let generation = UUID()
        currentGeneration = generation
        isRefreshing = true
        services = services.map { service in
            var updated = service
            updated.status = .testing
            updated.latencyMilliseconds = nil
            return updated
        }

        var remaining = services.count
        for service in services {
            var request = URLRequest(
                url: service.url,
                cachePolicy: .reloadIgnoringLocalCacheData,
                timeoutInterval: 7
            )
            request.httpMethod = "GET"
            request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")

            let startedAt = Date()
            let task = URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
                let elapsed = max(1, Int(Date().timeIntervalSince(startedAt) * 1000))
                DispatchQueue.main.async {
                    guard let self = self, self.currentGeneration == generation else { return }

                    if let index = self.services.firstIndex(where: { $0.id == service.id }) {
                        let statusCode = (response as? HTTPURLResponse)?.statusCode
                        let reachable = error == nil && statusCode.map { (200..<500).contains($0) } == true
                        self.services[index].status = reachable ? .reachable : .unavailable
                        self.services[index].latencyMilliseconds = reachable ? elapsed : nil
                    }

                    remaining -= 1
                    if remaining == 0 {
                        self.isRefreshing = false
                    }
                }
            }
            tasks.append(task)
            task.resume()
        }
    }
}
