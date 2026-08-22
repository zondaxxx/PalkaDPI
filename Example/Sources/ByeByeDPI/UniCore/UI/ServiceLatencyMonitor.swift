//
//  ServiceLatencyMonitor.swift
//  PalkaDPI
//

import Foundation
import SwiftUI

enum PalkaServiceProbeStatus: String, Codable {
    case idle
    case testing
    case reachable
    case partial
    case unavailable
}

struct PalkaServiceProbe: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    var status: PalkaServiceProbeStatus
    var latencyMilliseconds: Int?
    var dnsMilliseconds: Int?
    var tlsMilliseconds: Int?
    var successfulAttempts: Int
    var totalAttempts: Int
    var statusCode: Int?
    var checkedAt: Date?
    var errorText: String?

    var successRate: Double {
        totalAttempts == 0 ? 0 : Double(successfulAttempts) / Double(totalAttempts)
    }
}

private struct PalkaHTTPProbeMeasurement {
    let succeeded: Bool
    let totalMilliseconds: Int?
    let dnsMilliseconds: Int?
    let tlsMilliseconds: Int?
    let statusCode: Int?
    let errorText: String?
}

private final class PalkaHTTPProbe: NSObject, URLSessionDataDelegate, URLSessionTaskDelegate {
    private let completion: (PalkaHTTPProbeMeasurement) -> Void
    private let startedAt = Date()
    private var metrics: URLSessionTaskMetrics?
    private var receivedBytes = 0
    private var completed = false
    private var session: URLSession?

    init(url: URL, timeout: TimeInterval, completion: @escaping (PalkaHTTPProbeMeasurement) -> Void) {
        self.completion = completion
        super.init()

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpAdditionalHeaders = ["Cache-Control": "no-cache"]
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        self.session = session

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: timeout)
        request.httpMethod = "GET"
        session.dataTask(with: request).resume()
    }

    func cancel() {
        session?.invalidateAndCancel()
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        receivedBytes += data.count
        if receivedBytes > 128 * 1024 {
            dataTask.cancel()
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        self.metrics = metrics
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard !completed else { return }
        completed = true

        let statusCode = (task.response as? HTTPURLResponse)?.statusCode
        let succeeded = error == nil && statusCode.map { (200..<500).contains($0) } == true
        let transaction = metrics?.transactionMetrics.last
        let total = max(1, Int(Date().timeIntervalSince(startedAt) * 1000))
        let dns = Self.duration(
            from: transaction?.domainLookupStartDate,
            to: transaction?.domainLookupEndDate
        )
        let tls = Self.duration(
            from: transaction?.secureConnectionStartDate,
            to: transaction?.secureConnectionEndDate
        )

        completion(PalkaHTTPProbeMeasurement(
            succeeded: succeeded,
            totalMilliseconds: succeeded ? total : nil,
            dnsMilliseconds: dns,
            tlsMilliseconds: tls,
            statusCode: statusCode,
            errorText: error?.localizedDescription
        ))
        session.finishTasksAndInvalidate()
        self.session = nil
    }

    private static func duration(from start: Date?, to end: Date?) -> Int? {
        guard let start = start, let end = end else { return nil }
        return max(0, Int(end.timeIntervalSince(start) * 1000))
    }
}

final class ServiceDiagnosticsMonitor: ObservableObject {
    @Published private(set) var services: [PalkaServiceProbe] = []
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastCompletedAt: Date?

    private let defaults = UserDefaults(suiteName: Constants.APP_GROUP_ID) ?? .standard
    private let resultKey = "PalkaDPI.lastDiagnostics.v1"
    private var generation = UUID()
    private var probes: [PalkaHTTPProbe] = []

    init() {
        if let data = defaults.data(forKey: resultKey),
           let saved = try? JSONDecoder().decode([PalkaServiceProbe].self, from: data) {
            services = saved
            lastCompletedAt = saved.compactMap(\.checkedAt).max()
        }
    }

    deinit {
        probes.forEach { $0.cancel() }
    }

    func refresh(
        serviceIDs: [String],
        customDomains: [String] = [],
        attempts: Int = 2,
        completion: (([PalkaServiceProbe]) -> Void)? = nil
    ) {
        probes.forEach { $0.cancel() }
        probes.removeAll()

        let selected = PalkaService.diagnosticTargets(
            serviceIDs: serviceIDs,
            customDomains: customDomains
        )
        let safeAttempts = min(max(attempts, 1), 4)
        let currentGeneration = UUID()
        generation = currentGeneration
        isRefreshing = true
        services = selected.map {
            PalkaServiceProbe(
                id: $0.id,
                name: $0.name,
                status: .testing,
                latencyMilliseconds: nil,
                dnsMilliseconds: nil,
                tlsMilliseconds: nil,
                successfulAttempts: 0,
                totalAttempts: safeAttempts,
                statusCode: nil,
                checkedAt: nil,
                errorText: nil
            )
        }

        let group = DispatchGroup()
        var measurements: [String: [PalkaHTTPProbeMeasurement]] = [:]
        let measurementQueue = DispatchQueue(label: "PalkaDPI.DiagnosticMeasurements")

        for service in selected {
            for _ in 0..<safeAttempts {
                group.enter()
                let probe = PalkaHTTPProbe(url: service.probeURL, timeout: 7) { measurement in
                    measurementQueue.sync {
                        measurements[service.id, default: []].append(measurement)
                    }
                    group.leave()
                }
                probes.append(probe)
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self = self, self.generation == currentGeneration else { return }
            self.services = selected.map { service in
                let values = measurementQueue.sync { measurements[service.id] ?? [] }
                return self.aggregate(service: service, values: values, attempts: safeAttempts)
            }
            self.isRefreshing = false
            self.lastCompletedAt = Date()
            self.defaults.set(try? JSONEncoder().encode(self.services), forKey: self.resultKey)
            self.probes.removeAll()
            completion?(self.services)
        }
    }

    private func aggregate(
        service: PalkaService,
        values: [PalkaHTTPProbeMeasurement],
        attempts: Int
    ) -> PalkaServiceProbe {
        let successful = values.filter(\.succeeded)
        let status: PalkaServiceProbeStatus
        if successful.count == attempts {
            status = .reachable
        } else if !successful.isEmpty {
            status = .partial
        } else {
            status = .unavailable
        }

        return PalkaServiceProbe(
            id: service.id,
            name: service.name,
            status: status,
            latencyMilliseconds: median(successful.compactMap(\.totalMilliseconds)),
            dnsMilliseconds: median(successful.compactMap(\.dnsMilliseconds)),
            tlsMilliseconds: median(successful.compactMap(\.tlsMilliseconds)),
            successfulAttempts: successful.count,
            totalAttempts: attempts,
            statusCode: successful.compactMap(\.statusCode).last ?? values.compactMap(\.statusCode).last,
            checkedAt: Date(),
            errorText: values.compactMap(\.errorText).last
        )
    }

    private func median(_ values: [Int]) -> Int? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        if sorted.count % 2 == 1 { return sorted[sorted.count / 2] }
        return (sorted[(sorted.count / 2) - 1] + sorted[sorted.count / 2]) / 2
    }
}
