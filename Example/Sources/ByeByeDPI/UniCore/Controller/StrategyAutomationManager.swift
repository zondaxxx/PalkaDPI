//
//  StrategyAutomationManager.swift
//  PalkaDPI
//

import Foundation
import SwiftUI
import SwByeDPI
#if canImport(UIKit)
import UIKit
#endif

struct PalkaStrategyTestScore: Identifiable, Equatable {
    let id: String
    let name: String
    let succeededServices: Int
    let totalServices: Int
    let medianLatencyMilliseconds: Int?
    let score: Int
    /// Services whose bulk transfer started and then froze (TSPU signature).
    var stalledServices: Int = 0
    /// Median bulk throughput across services that completed the 256 KB probe.
    var bulkKilobytesPerSecond: Int? = nil
}

struct PalkaRecoverySuggestion: Identifiable, Equatable {
    let id: String
    let name: String
    let commandTemplate: [String]
}

final class StrategyAutomationManager: ObservableObject {
    /// After the tunnel-free pre-check, only this many best candidates are
    /// confirmed through the real packet tunnel (each tunnel cycle costs 10-20 s).
    static let tunnelConfirmationLimit = 3

    @Published private(set) var isRunning = false
    @Published private(set) var currentStrategyName = ""
    @Published private(set) var currentStage = ""
    @Published private(set) var completedStrategies = 0
    @Published private(set) var totalStrategies = 0
    @Published private(set) var scores: [PalkaStrategyTestScore] = []
    @Published private(set) var bestStrategyName: String? = nil
    @Published private(set) var errorText: String? = nil
    @Published private(set) var screeningSummary: String? = nil
    @Published var recoverySuggestion: PalkaRecoverySuggestion? = nil

    private let properties: AppProperties
    private let neManager: NEObservableManager
    private let catalog: OnlineStrategyCatalogStore
    private let library: StrategyLibraryStore
    private let diagnostics: ServiceDiagnosticsMonitor
    private let network: NetworkEnvironmentMonitor
    private let screener = SBDTestController()
    private var generation = UUID()
    private var failureStreak = 0
    private var recoveryTimer: Timer?

    init(
        properties: AppProperties,
        neManager: NEObservableManager,
        catalog: OnlineStrategyCatalogStore,
        library: StrategyLibraryStore,
        diagnostics: ServiceDiagnosticsMonitor,
        network: NetworkEnvironmentMonitor
    ) {
        self.properties = properties
        self.neManager = neManager
        self.catalog = catalog
        self.library = library
        self.diagnostics = diagnostics
        self.network = network

        recoveryTimer = Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { [weak self] _ in
            self?.runRecoveryCheckIfNeeded()
        }
    }

    deinit {
        recoveryTimer?.invalidate()
    }

    func startAutoSelection() {
        guard !isRunning else { return }
        guard !catalog.strategies.isEmpty else {
            errorText = palkaLocalized("palkaAutoCatalogNeeded")
            catalog.load()
            return
        }

        let candidates = catalog.strategies.sorted { left, right in
            let leftFavorite = library.isFavorite(left.id)
            let rightFavorite = library.isFavorite(right.id)
            return leftFavorite && !rightFavorite
        }
        let previousID = properties.activeStrategyID
        let previousName = properties.activeStrategyName
        let previousTemplate = UserDefaultsAppProperties.activeStrategyTemplateArgs
        let shouldReconnectOnFailure = neManager.vpnRunning

        generation = UUID()
        let currentGeneration = generation
        isRunning = true
        currentStage = palkaLocalized("palkaAutoStoppingVPN")
        errorText = nil
        bestStrategyName = nil
        screeningSummary = nil
        completedStrategies = 0
        totalStrategies = candidates.count
        scores = []

        let finish: () -> Void = { [weak self] in
            guard let self = self, self.generation == currentGeneration else { return }
            let best = self.scores.sorted {
                if $0.succeededServices != $1.succeededServices {
                    return $0.succeededServices > $1.succeededServices
                }
                if $0.score != $1.score {
                    return $0.score < $1.score
                }
                return ($0.bulkKilobytesPerSecond ?? 0) > ($1.bulkKilobytesPerSecond ?? 0)
            }.first

            guard let best = best,
                  best.succeededServices > 0,
                  let strategy = candidates.first(where: { $0.id == best.id }) else {
                self.properties.applyCatalogStrategy(
                    id: previousID,
                    name: previousName,
                    commandTemplate: previousTemplate.isEmpty
                        ? PalkaPreset.recommendedTemplateArgs
                        : previousTemplate
                )
                self.isRunning = false
                self.errorText = palkaLocalized("palkaAutoNoWorkingStrategy")
                if shouldReconnectOnFailure {
                    self.currentStage = palkaLocalized("palkaAutoConnectingVPN")
                    self.neManager.startConnection { [weak self] _, _ in
                        DispatchQueue.main.async {
                            self?.currentStage = ""
                        }
                    }
                } else {
                    self.currentStage = ""
                }
                return
            }

            self.properties.applyCatalogStrategy(
                id: strategy.id,
                name: strategy.displayName,
                commandTemplate: strategy.commandArgs
            )
            self.properties.saveCurrentStrategy(for: self.network.kind)
            self.bestStrategyName = strategy.displayName
            self.currentStrategyName = strategy.displayName
            self.currentStage = palkaLocalized("palkaAutoConnectingVPN")
            self.neManager.startConnection { [weak self] success, error in
                DispatchQueue.main.async {
                    self?.isRunning = false
                    self?.currentStage = ""
                    if !success {
                        self?.errorText = error?.localizedDescription
                            ?? palkaLocalized("palkaAutoStartFailed")
                    }
                }
            }
        }

        // Phase 1: stop the system VPN once and pre-check every candidate with the
        // in-process ByeDPI SOCKS listener (no tunnel restarts, ~2-4 s per profile).
        // Phase 2: confirm only the shortlist through the real packet tunnel with
        // bulk probes and packet-counter verification.
        neManager.stopConnection { [weak self] _, _ in
            DispatchQueue.main.async {
                guard let self = self, self.generation == currentGeneration else { return }
                self.currentStage = palkaLocalized("palkaAutoScreening")
                self.screen(candidates: candidates, generation: currentGeneration) { [weak self] shortlist, summary in
                    guard let self = self, self.generation == currentGeneration else { return }
                    self.screeningSummary = summary
                    self.completedStrategies = 0
                    self.totalStrategies = shortlist.count
                    self.test(
                        candidates: shortlist,
                        index: 0,
                        generation: currentGeneration,
                        completion: finish
                    )
                }
            }
        }
    }

    func cancel() {
        generation = UUID()
        isRunning = false
        currentStrategyName = ""
        currentStage = palkaLocalized("palkaAutoStoppingVPN")
        screener.cancelTest()
        neManager.stopConnection { [weak self] _, _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.currentStage = ""
                self.diagnostics.refresh(
                    serviceIDs: self.properties.selectedServiceIDs,
                    customDomains: self.properties.customServiceDomains,
                    attempts: 1
                )
            }
        }
    }

    func evaluateRecovery(results: [PalkaServiceProbe]) {
        guard properties.smartRecoveryEnabled,
              neManager.vpnRunning,
              !isRunning,
              !results.isEmpty else {
            failureStreak = 0
            return
        }

        let hasReachableService = results.contains { $0.status == .reachable || $0.status == .partial }
        if hasReachableService {
            failureStreak = 0
            recoverySuggestion = nil
            return
        }

        failureStreak += 1
        guard failureStreak >= 2,
              recoverySuggestion == nil,
              let fallback = library.bestFallback(excluding: properties.activeStrategyID) else { return }
        recoverySuggestion = PalkaRecoverySuggestion(
            id: fallback.id,
            name: fallback.name,
            commandTemplate: fallback.commandTemplate
        )
    }

    func acceptRecoverySuggestion() {
        guard let suggestion = recoverySuggestion else { return }
        recoverySuggestion = nil
        failureStreak = 0
        neManager.stopConnection { [weak self] stopped, _ in
            guard let self = self, stopped else { return }
            DispatchQueue.main.async {
                self.properties.applyCatalogStrategy(
                    id: suggestion.id,
                    name: suggestion.name,
                    commandTemplate: suggestion.commandTemplate
                )
                self.neManager.startConnection { _, _ in }
            }
        }
    }

    func dismissRecoverySuggestion() {
        recoverySuggestion = nil
        failureStreak = 0
    }

    private func runRecoveryCheckIfNeeded() {
        guard properties.smartRecoveryEnabled, neManager.vpnRunning, !isRunning else { return }
        #if canImport(UIKit) && !os(watchOS)
        // Do not burn battery and service quota while the app is in the background;
        // the next foreground diagnostics refresh feeds evaluateRecovery anyway.
        guard UIApplication.shared.applicationState == .active else { return }
        #endif
        diagnostics.refresh(
            serviceIDs: properties.selectedServiceIDs,
            customDomains: properties.customServiceDomains,
            attempts: 2,
            includeBulk: false
        ) { [weak self] results in
            self?.evaluateRecovery(results: results)
        }
    }

    /// Tunnel-free pre-check: runs every candidate as an in-process SOCKS proxy and
    /// fetches the service probe URLs through it. Returns the shortlist to confirm
    /// through the tunnel, or all candidates when the pre-check is inconclusive
    /// (listener busy, operator DNS poisoning without DoH, nothing passed).
    private func screen(
        candidates: [OnlineStrategy],
        generation: UUID,
        completion: @escaping ([OnlineStrategy], String?) -> Void
    ) {
        let serviceIDs = properties.selectedServiceIDs
        let customDomains = properties.customServiceDomains
        let domains = PalkaService.diagnosticTargets(
            serviceIDs: serviceIDs,
            customDomains: customDomains
        ).map { $0.probeURL.absoluteString }

        var lookup: [Int: OnlineStrategy] = [:]
        var strategies: [SBDStrategy] = []
        for candidate in candidates {
            guard let args = candidate.resolvedCommandArgs(
                serviceIDs: serviceIDs,
                customDomains: customDomains
            ) else { continue }
            let strategy = SBDStrategy(cmdArgs: args)
            guard lookup[strategy.id] == nil else { continue }
            lookup[strategy.id] = candidate
            strategies.append(strategy)
        }

        guard strategies.count > Self.tunnelConfirmationLimit,
              !domains.isEmpty,
              screener.canStartTest else {
            completion(candidates, nil)
            return
        }

        let config = SBDTestConfig(
            domainRequestsCount: 1,
            parallelRequestsCount: UInt8(min(max(domains.count, 1), 4)),
            domainAnswerTimeoutInS: 4,
            delayBetweenRequestsInS: 0,
            fakeSNI: "google.com",
            domainListIDs: Set<String>(),
            strategyListIDs: Set<String>()
        )
        screener.test(config: config, domains: domains, strategies: strategies) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self, self.generation == generation else { return }
                switch result {
                case .failure:
                    completion(candidates, nil)
                case .success(let results):
                    let ranked = results.sorted {
                        $0.successDomainRequestsCount > $1.successDomainRequestsCount
                    }
                    let passing = ranked.filter { $0.successDomainRequestsCount > 0 }
                    guard !passing.isEmpty else {
                        completion(candidates, palkaLocalized("palkaAutoScreeningNone"))
                        return
                    }
                    let shortlist = passing
                        .prefix(Self.tunnelConfirmationLimit)
                        .compactMap { lookup[$0.strategy.id] }
                    guard !shortlist.isEmpty else {
                        completion(candidates, nil)
                        return
                    }
                    let summary = String(
                        format: palkaLocalized("palkaAutoScreeningSummaryFormat"),
                        passing.count,
                        results.count,
                        shortlist.count
                    )
                    completion(shortlist, summary)
                }
            }
        }
    }

    private func test(
        candidates: [OnlineStrategy],
        index: Int,
        generation: UUID,
        completion: @escaping () -> Void
    ) {
        guard self.generation == generation else { return }
        guard index < candidates.count else {
            currentStage = palkaLocalized("palkaAutoStoppingVPN")
            neManager.stopConnection { _, _ in
                DispatchQueue.main.async(execute: completion)
            }
            return
        }

        let strategy = candidates[index]
        currentStrategyName = strategy.displayName
        currentStage = palkaLocalized("palkaAutoStoppingVPN")
        neManager.stopConnection { [weak self] stopped, stopError in
            DispatchQueue.main.async {
                guard let self = self, self.generation == generation else { return }
                guard stopped else {
                    self.errorText = stopError?.localizedDescription
                    self.appendScore(strategy: strategy, results: [])
                    self.completedStrategies += 1
                    self.test(
                        candidates: candidates,
                        index: index + 1,
                        generation: generation,
                        completion: completion
                    )
                    return
                }

                self.properties.applyCatalogStrategy(
                    id: strategy.id,
                    name: strategy.displayName,
                    commandTemplate: strategy.commandArgs
                )
                self.errorText = nil
                self.currentStage = palkaLocalized("palkaAutoConnectingVPN")
                self.neManager.startConnection { [weak self] success, error in
                    DispatchQueue.main.async {
                        guard let self = self, self.generation == generation else { return }
                        guard success else {
                            self.errorText = error?.localizedDescription
                            self.appendScore(strategy: strategy, results: [])
                            self.completedStrategies += 1
                            self.test(
                                candidates: candidates,
                                index: index + 1,
                                generation: generation,
                                completion: completion
                            )
                            return
                        }

                        // startConnection completes only after NetworkExtension has
                        // reached .connected, so these requests cannot race the tunnel.
                        self.currentStage = palkaLocalized("palkaAutoProbingThroughVPN")
                        self.diagnostics.refresh(
                            serviceIDs: self.properties.selectedServiceIDs,
                            customDomains: self.properties.customServiceDomains,
                            attempts: 2,
                            includeBulk: true
                        ) { [weak self] results in
                            guard let self = self, self.generation == generation else { return }
                            self.currentStage = palkaLocalized("palkaAutoVerifyingTraffic")
                            self.verifyTunnelTraffic(
                                generation: generation,
                                deadline: Date().addingTimeInterval(3)
                            ) { [weak self] trafficVerified in
                                guard let self = self, self.generation == generation else { return }
                                // A connected NE status is not enough: a dead tun2socks
                                // path can let probes fail or fall back without ever
                                // producing a packet. Only score results after the
                                // extension confirms that its core processed traffic.
                                let tunnelVerifiedResults = trafficVerified ? results : []
                                if !trafficVerified {
                                    self.errorText = palkaLocalized("palkaAutoNoTunnelTraffic")
                                }
                                self.appendScore(strategy: strategy, results: tunnelVerifiedResults)
                                self.completedStrategies += 1
                                self.test(
                                    candidates: candidates,
                                    index: index + 1,
                                    generation: generation,
                                    completion: completion
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    private func verifyTunnelTraffic(
        generation: UUID,
        deadline: Date,
        completion: @escaping (Bool) -> Void
    ) {
        guard self.generation == generation, neManager.vpnRunning else {
            completion(false)
            return
        }
        neManager.refreshTunnelStats()
        if let stats = neManager.tunnelStats,
           stats.coreRunning,
           stats.totalPackets > 0 {
            completion(true)
            return
        }
        guard Date() < deadline else {
            completion(false)
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.verifyTunnelTraffic(
                generation: generation,
                deadline: deadline,
                completion: completion
            )
        }
    }

    private func appendScore(strategy: OnlineStrategy, results: [PalkaServiceProbe]) {
        // "Works" now means the bulk transfer on the real delivery host completed,
        // not only that a tiny robots.txt came back: a stalled bulk probe counts as
        // a failure for ranking even though the service is shown as "partial".
        let successful = results.filter {
            ($0.status == .reachable || $0.status == .partial) && $0.bulkStalled != true
        }
        let stalled = results.filter { $0.bulkStalled == true }
        let latencies = successful.compactMap(\.latencyMilliseconds).sorted()
        let median = latencies.isEmpty ? nil : latencies[latencies.count / 2]
        let throughputs = successful.compactMap(\.bulkKilobytesPerSecond).sorted()
        let medianThroughput = throughputs.isEmpty ? nil : throughputs[throughputs.count / 2]
        let targetCount = PalkaService.diagnosticTargets(
            serviceIDs: properties.selectedServiceIDs,
            customDomains: properties.customServiceDomains
        ).count
        let failures = max(targetCount - successful.count, 0)
        let scoreValue = failures * 100_000 + stalled.count * 20_000 + (median ?? 99_999)
        let score = PalkaStrategyTestScore(
            id: strategy.id,
            name: strategy.displayName,
            succeededServices: successful.count,
            totalServices: max(results.count, targetCount),
            medianLatencyMilliseconds: median,
            score: scoreValue,
            stalledServices: stalled.count,
            bulkKilobytesPerSecond: medianThroughput
        )
        scores.append(score)
        library.record(
            strategyID: strategy.id,
            name: strategy.displayName,
            commandTemplate: strategy.commandArgs,
            succeeded: !successful.isEmpty,
            latencyMilliseconds: median
        )
    }
}
