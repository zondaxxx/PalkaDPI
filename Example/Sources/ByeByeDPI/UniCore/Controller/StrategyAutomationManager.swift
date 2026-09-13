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
    /// The Packet Tunnel extension keeps 127.0.0.1:10800 for a few seconds after
    /// NetworkExtension reports "disconnected"; the pre-check core uses its own port.
    static let screeningListenPort: UInt16 = 10801
    /// Hard deadlines: nothing in automation may wait on a callback forever.
    static let screeningDeadlineSeconds: TimeInterval = 75
    static let tunnelStrategyDeadlineSeconds: TimeInterval = 70

    @Published private(set) var isRunning = false
    @Published private(set) var currentStrategyName = ""
    @Published private(set) var currentStage = ""
    @Published private(set) var completedStrategies = 0
    @Published private(set) var totalStrategies = 0
    @Published private(set) var scores: [PalkaStrategyTestScore] = []
    @Published private(set) var bestStrategyName: String? = nil
    @Published private(set) var errorText: String? = nil
    @Published private(set) var screeningSummary: String? = nil
    /// Human-readable trace of the last run, newest last. Shown on the automation
    /// screen so a stuck run can be diagnosed without a debugger.
    @Published private(set) var logLines: [String] = []
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
    private var screeningObservers: [NSObjectProtocol] = []
    private var stepWatchdog: DispatchWorkItem?
    private let logFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

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
        removeScreeningObservers()
    }

    // MARK: - Public flow

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
        logLines = []
        log("start: \(candidates.count) strategies, services \(properties.selectedServiceIDs.joined(separator: ","))")

        let finish: () -> Void = { [weak self] in
            guard let self = self, self.generation == currentGeneration else { return }
            self.clearStepWatchdog()
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
                self.log("no working strategy; restoring previous")
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

            self.log("best: \(strategy.displayName) (\(best.succeededServices)/\(best.totalServices))")
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
                    guard let self = self else { return }
                    self.isRunning = false
                    self.currentStage = ""
                    if success {
                        self.log("connected with \(strategy.displayName)")
                    } else {
                        self.log("final connect failed: \(error?.localizedDescription ?? "-")")
                        self.errorText = error?.localizedDescription
                            ?? palkaLocalized("palkaAutoStartFailed")
                    }
                }
            }
        }

        // Phase 1: stop the system VPN once and pre-check every candidate with the
        // in-process ByeDPI SOCKS listener (no tunnel restarts, ~2-4 s per profile).
        // Phase 2: confirm only the shortlist through the real packet tunnel with
        // bulk probes and packet-counter verification. If the shortlist yields
        // nothing, the remaining candidates are still tried through the tunnel.
        armStepWatchdog(seconds: 20, generation: currentGeneration, label: "stop VPN")
        neManager.stopConnection { [weak self] stopped, stopError in
            DispatchQueue.main.async {
                guard let self = self, self.generation == currentGeneration else { return }
                self.clearStepWatchdog()
                self.log(stopped ? "VPN stopped" : "VPN stop failed: \(stopError?.localizedDescription ?? "-")")
                self.currentStage = palkaLocalized("palkaAutoScreening")
                self.screen(candidates: candidates, generation: currentGeneration) { [weak self] shortlist, summary in
                    guard let self = self, self.generation == currentGeneration else { return }
                    self.screeningSummary = summary
                    self.completedStrategies = 0
                    self.totalStrategies = shortlist.count
                    let rest = candidates.filter { candidate in !shortlist.contains { $0.id == candidate.id } }
                    self.test(candidates: shortlist, index: 0, generation: currentGeneration) { [weak self] in
                        guard let self = self, self.generation == currentGeneration else { return }
                        let anySuccess = self.scores.contains { $0.succeededServices > 0 }
                        guard !anySuccess, !rest.isEmpty else {
                            finish()
                            return
                        }
                        self.log("shortlist failed; testing remaining \(rest.count) through the tunnel")
                        self.errorText = palkaLocalized("palkaAutoTestingRest")
                        self.completedStrategies = 0
                        self.totalStrategies = rest.count
                        self.test(candidates: rest, index: 0, generation: currentGeneration, completion: finish)
                    }
                }
            }
        }
    }

    func cancel() {
        generation = UUID()
        clearStepWatchdog()
        removeScreeningObservers()
        isRunning = false
        currentStrategyName = ""
        currentStage = palkaLocalized("palkaAutoStoppingVPN")
        log("cancelled by user")
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

    // MARK: - Recovery

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

    // MARK: - Logging and watchdogs

    private func log(_ message: String) {
        let line = "\(logFormatter.string(from: Date())) \(message)"
        logLines.append(line)
        if logLines.count > 80 {
            logLines.removeFirst(logLines.count - 80)
        }
    }

    /// Fires `onTimeout` on the main queue unless `clearStepWatchdog` runs first.
    /// Every automation step is wrapped so a lost NetworkExtension or tester
    /// callback can never leave the screen spinning forever.
    private func armStepWatchdog(
        seconds: TimeInterval,
        generation: UUID,
        label: String,
        onTimeout: (() -> Void)? = nil
    ) {
        clearStepWatchdog()
        let item = DispatchWorkItem { [weak self] in
            guard let self = self, self.generation == generation else { return }
            self.stepWatchdog = nil
            self.log("timeout: \(label) did not finish in \(Int(seconds)) s")
            onTimeout?()
        }
        stepWatchdog = item
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: item)
    }

    private func clearStepWatchdog() {
        stepWatchdog?.cancel()
        stepWatchdog = nil
    }

    private func removeScreeningObservers() {
        screeningObservers.forEach { NotificationCenter.default.removeObserver($0) }
        screeningObservers.removeAll()
    }

    // MARK: - Phase 1: tunnel-free pre-check

    /// Runs every candidate as an in-process SOCKS proxy and fetches the service
    /// probe URLs through it. Returns the shortlist to confirm through the tunnel,
    /// or all candidates when the pre-check is inconclusive (listener busy,
    /// operator DNS poisoning without DoH, nothing passed, deadline hit).
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
            log("pre-check skipped (\(strategies.count) strategies, tester busy: \(!screener.canStartTest))")
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
            strategyListIDs: Set<String>(),
            listenPort: Self.screeningListenPort
        )
        completedStrategies = 0
        totalStrategies = strategies.count
        log("pre-check: \(strategies.count) strategies on 127.0.0.1:\(Self.screeningListenPort)")

        // Live progress from the tester: which strategy is running and how many finished.
        removeScreeningObservers()
        screeningObservers = [
            NotificationCenter.default.addObserver(
                forName: .SBDTestingStrategyUpdate, object: nil, queue: .main
            ) { [weak self] notification in
                guard let self = self, self.generation == generation else { return }
                let (parsed, strategy) = notification.tryParseTestingStrategyFromNotification()
                guard parsed, let strategy = strategy, let candidate = lookup[strategy.id] else { return }
                self.currentStrategyName = candidate.displayName
            },
            NotificationCenter.default.addObserver(
                forName: .SBDTestedStrategy, object: nil, queue: .main
            ) { [weak self] notification in
                guard let self = self, self.generation == generation else { return }
                let (parsed, result) = notification.tryParseTestedStrategyFromNotification()
                guard parsed, let result = result else { return }
                self.completedStrategies = min(self.completedStrategies + 1, self.totalStrategies)
                let name = lookup[result.strategy.id]?.displayName ?? "?"
                self.log("pre-check \(name): \(result.successDomainRequestsCount)/\(result.successDomainRequestsCount + result.failedDomainRequestsCount)")
            },
        ]

        var finished = false
        let finishOnce: ([OnlineStrategy], String?) -> Void = { [weak self] shortlist, summary in
            guard let self = self, !finished else { return }
            finished = true
            self.clearStepWatchdog()
            self.removeScreeningObservers()
            completion(shortlist, summary)
        }

        armStepWatchdog(seconds: Self.screeningDeadlineSeconds, generation: generation, label: "pre-check") { [weak self] in
            self?.screener.cancelTest()
            finishOnce(candidates, palkaLocalized("palkaAutoScreeningTimeout"))
        }

        screener.test(config: config, domains: domains, strategies: strategies) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self, self.generation == generation else { return }
                switch result {
                case .failure(let error):
                    self.log("pre-check failed: \(error)")
                    finishOnce(candidates, nil)
                case .success(let results):
                    let ranked = results.sorted {
                        $0.successDomainRequestsCount > $1.successDomainRequestsCount
                    }
                    let passing = ranked.filter { $0.successDomainRequestsCount > 0 }
                    guard !passing.isEmpty else {
                        self.log("pre-check: nothing passed, falling back to full tunnel run")
                        finishOnce(candidates, palkaLocalized("palkaAutoScreeningNone"))
                        return
                    }
                    let shortlist = passing
                        .prefix(Self.tunnelConfirmationLimit)
                        .compactMap { lookup[$0.strategy.id] }
                    guard !shortlist.isEmpty else {
                        finishOnce(candidates, nil)
                        return
                    }
                    let summary = String(
                        format: palkaLocalized("palkaAutoScreeningSummaryFormat"),
                        passing.count,
                        results.count,
                        shortlist.count
                    )
                    self.log("pre-check done: \(passing.count)/\(results.count) passed; shortlist \(shortlist.map(\.displayName).joined(separator: ", "))")
                    finishOnce(shortlist, summary)
                }
            }
        }
    }

    // MARK: - Phase 2: confirmation through the packet tunnel

    private func test(
        candidates: [OnlineStrategy],
        index: Int,
        generation: UUID,
        completion: @escaping () -> Void
    ) {
        guard self.generation == generation else { return }
        guard index < candidates.count else {
            currentStage = palkaLocalized("palkaAutoStoppingVPN")
            armStepWatchdog(seconds: 20, generation: generation, label: "final stop") {
                completion()
            }
            neManager.stopConnection { [weak self] _, _ in
                DispatchQueue.main.async {
                    guard let self = self, self.generation == generation else { return }
                    self.clearStepWatchdog()
                    completion()
                }
            }
            return
        }

        let strategy = candidates[index]
        var stepDone = false
        let advance: (String, [PalkaServiceProbe]) -> Void = { [weak self] reason, results in
            guard let self = self, self.generation == generation, !stepDone else { return }
            stepDone = true
            self.clearStepWatchdog()
            self.log("\(strategy.displayName): \(reason)")
            self.appendScore(strategy: strategy, results: results)
            self.completedStrategies += 1
            self.test(
                candidates: candidates,
                index: index + 1,
                generation: generation,
                completion: completion
            )
        }

        currentStrategyName = strategy.displayName
        currentStage = palkaLocalized("palkaAutoStoppingVPN")
        log("tunnel test \(index + 1)/\(candidates.count): \(strategy.displayName)")
        armStepWatchdog(seconds: Self.tunnelStrategyDeadlineSeconds, generation: generation, label: strategy.displayName) {
            advance("timed out", [])
        }

        neManager.stopConnection { [weak self] stopped, stopError in
            DispatchQueue.main.async {
                guard let self = self, self.generation == generation, !stepDone else { return }
                guard stopped else {
                    self.errorText = stopError?.localizedDescription
                    advance("VPN stop failed: \(stopError?.localizedDescription ?? "-")", [])
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
                        guard let self = self, self.generation == generation, !stepDone else { return }
                        guard success else {
                            self.errorText = error?.localizedDescription
                            advance("VPN start failed: \(error?.localizedDescription ?? "-")", [])
                            return
                        }

                        // startConnection completes only after NetworkExtension has
                        // reached .connected, so these requests cannot race the tunnel.
                        self.log("\(strategy.displayName): tunnel up, probing")
                        self.currentStage = palkaLocalized("palkaAutoProbingThroughVPN")
                        self.diagnostics.refresh(
                            serviceIDs: self.properties.selectedServiceIDs,
                            customDomains: self.properties.customServiceDomains,
                            attempts: 2,
                            includeBulk: true
                        ) { [weak self] results in
                            guard let self = self, self.generation == generation, !stepDone else { return }
                            self.currentStage = palkaLocalized("palkaAutoVerifyingTraffic")
                            self.verifyTunnelTraffic(
                                generation: generation,
                                deadline: Date().addingTimeInterval(3)
                            ) { [weak self] trafficVerified in
                                guard let self = self, self.generation == generation, !stepDone else { return }
                                // A connected NE status is not enough: a dead tun2socks
                                // path can let probes fail or fall back without ever
                                // producing a packet. Only score results after the
                                // extension confirms that its core processed traffic.
                                if !trafficVerified {
                                    self.errorText = palkaLocalized("palkaAutoNoTunnelTraffic")
                                    advance("no packets through tun2socks", [])
                                    return
                                }
                                let summary = results.map { probe -> String in
                                    let state: String
                                    switch probe.status {
                                    case .reachable: state = "ok"
                                    case .partial: state = probe.bulkStalled == true ? "stall" : "partial"
                                    default: state = "fail"
                                    }
                                    return "\(probe.name)=\(state)"
                                }.joined(separator: " ")
                                advance(summary, results)
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
