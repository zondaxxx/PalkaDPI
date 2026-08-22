//
//  StrategyAutomationManager.swift
//  PalkaDPI
//

import Foundation
import SwiftUI

struct PalkaStrategyTestScore: Identifiable, Equatable {
    let id: String
    let name: String
    let succeededServices: Int
    let totalServices: Int
    let medianLatencyMilliseconds: Int?
    let score: Int
}

struct PalkaRecoverySuggestion: Identifiable, Equatable {
    let id: String
    let name: String
    let commandTemplate: [String]
}

final class StrategyAutomationManager: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var currentStrategyName = ""
    @Published private(set) var currentStage = ""
    @Published private(set) var completedStrategies = 0
    @Published private(set) var totalStrategies = 0
    @Published private(set) var scores: [PalkaStrategyTestScore] = []
    @Published private(set) var bestStrategyName: String? = nil
    @Published private(set) var errorText: String? = nil
    @Published var recoverySuggestion: PalkaRecoverySuggestion? = nil

    private let properties: AppProperties
    private let neManager: NEObservableManager
    private let catalog: OnlineStrategyCatalogStore
    private let library: StrategyLibraryStore
    private let diagnostics: ServiceDiagnosticsMonitor
    private let network: NetworkEnvironmentMonitor
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

        recoveryTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
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
        completedStrategies = 0
        totalStrategies = candidates.count
        scores = []

        test(
            candidates: candidates,
            index: 0,
            generation: currentGeneration
        ) { [weak self] in
            guard let self = self, self.generation == currentGeneration else { return }
            let best = self.scores.sorted {
                if $0.succeededServices != $1.succeededServices {
                    return $0.succeededServices > $1.succeededServices
                }
                return $0.score < $1.score
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
    }

    func cancel() {
        generation = UUID()
        isRunning = false
        currentStrategyName = ""
        currentStage = palkaLocalized("palkaAutoStoppingVPN")
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
        diagnostics.refresh(
            serviceIDs: properties.selectedServiceIDs,
            customDomains: properties.customServiceDomains,
            attempts: 2
        ) { [weak self] results in
            self?.evaluateRecovery(results: results)
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
                            attempts: 2
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
        let successful = results.filter { $0.status == .reachable || $0.status == .partial }
        let latencies = successful.compactMap(\.latencyMilliseconds).sorted()
        let median = latencies.isEmpty ? nil : latencies[latencies.count / 2]
        let targetCount = PalkaService.diagnosticTargets(
            serviceIDs: properties.selectedServiceIDs,
            customDomains: properties.customServiceDomains
        ).count
        let failures = max(targetCount - successful.count, 0)
        let scoreValue = failures * 100_000 + (median ?? 99_999)
        let score = PalkaStrategyTestScore(
            id: strategy.id,
            name: strategy.displayName,
            succeededServices: successful.count,
            totalServices: max(results.count, targetCount),
            medianLatencyMilliseconds: median,
            score: scoreValue
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
