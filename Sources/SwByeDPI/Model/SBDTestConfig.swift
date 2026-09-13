//
//  SBDTestConfig.swift
//  SwByeDPI
//
//  Created by developer on 19.02.2026.
//

import Foundation

/// ByeDPI optimal strategy define config
public final class SBDTestConfig: Codable, Sendable, Cloneable {
    
    /// Domain DPI-evasion strategy tests count. Bigger - more accurate results, but requires more time
    public let domainRequestsCount: UInt8
    /// Parallel DPI-evasion tests count in a time. Bigger - check speed up, but may give false-positive results
    public let parallelRequestsCount: UInt8
    /// Domain answer wait timeout in seconds
    public let domainAnswerTimeoutInS: UInt8
    /// Delay in seconds between each test request
    public let delayBetweenRequestsInS: UInt8
    /// Fake Server Name Indication (SNI) during TLS handshake
    public let fakeSNI: String
    /// Used domain list IDs
    public let domainListIDs: Set<String>
    /// Used DPI-evasion strategy list IDs
    public let strategyListIDs: Set<String>
    /// Local SOCKS listen port used by the in-process ByeDPI core during the test.
    /// A Packet Tunnel extension that is still shutting down may hold the default
    /// port, so callers that run while a tunnel exists should pick another one.
    public let listenPort: UInt16

    private enum CodingKeys: String, CodingKey {
        case domainRequestsCount, parallelRequestsCount, domainAnswerTimeoutInS, delayBetweenRequestsInS, fakeSNI, domainListIDs, strategyListIDs, listenPort
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        domainRequestsCount = max(1, (try? c.decode(UInt8.self, forKey: .domainRequestsCount)) ?? 1)
        parallelRequestsCount = max(1, (try? c.decode(UInt8.self, forKey: .parallelRequestsCount)) ?? 1)
        domainAnswerTimeoutInS = max(1, (try? c.decode(UInt8.self, forKey: .domainAnswerTimeoutInS)) ?? 5)
        delayBetweenRequestsInS = (try? c.decode(UInt8.self, forKey: .delayBetweenRequestsInS)) ?? 0
        let sni = (try? c.decode(String.self, forKey: .fakeSNI)) ?? ""
        fakeSNI = sni.isEmpty ? "google.com" : sni
        domainListIDs = (try? c.decode(Set<String>.self, forKey: .domainListIDs)) ?? []
        strategyListIDs = (try? c.decode(Set<String>.self, forKey: .strategyListIDs)) ?? []
        let port = (try? c.decode(UInt16.self, forKey: .listenPort)) ?? SBDConfig.defaultListenPort
        listenPort = port == 0 ? SBDConfig.defaultListenPort : port
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(domainRequestsCount, forKey: .domainRequestsCount)
        try c.encode(parallelRequestsCount, forKey: .parallelRequestsCount)
        try c.encode(domainAnswerTimeoutInS, forKey: .domainAnswerTimeoutInS)
        try c.encode(delayBetweenRequestsInS, forKey: .delayBetweenRequestsInS)
        try c.encode(fakeSNI, forKey: .fakeSNI)
        try c.encode(domainListIDs, forKey: .domainListIDs)
        try c.encode(strategyListIDs, forKey: .strategyListIDs)
        try c.encode(listenPort, forKey: .listenPort)
    }
    
    public init(domainRequestsCount: UInt8, parallelRequestsCount: UInt8, domainAnswerTimeoutInS: UInt8, delayBetweenRequestsInS: UInt8, fakeSNI: String, domainListIDs: Set<String>, strategyListIDs: Set<String>, listenPort: UInt16 = SBDConfig.defaultListenPort) {
        self.listenPort = listenPort == 0 ? SBDConfig.defaultListenPort : listenPort
        if (domainRequestsCount == 0) {
#if DEBUG
            print("Invalid domain requests count. Set 1")
#endif
            self.domainRequestsCount = 1
        } else {
            self.domainRequestsCount = domainRequestsCount
        }
        if (parallelRequestsCount == 0) {
#if DEBUG
            print("Invalid parallel requests count. Set 1")
#endif
            self.parallelRequestsCount = 1
        } else {
            self.parallelRequestsCount = parallelRequestsCount
        }
        if (domainAnswerTimeoutInS == 0) {
#if DEBUG
            print("Invalid response timeout. Set 1")
#endif
            self.domainAnswerTimeoutInS = 1
        } else {
            self.domainAnswerTimeoutInS = domainAnswerTimeoutInS
        }
        self.delayBetweenRequestsInS = delayBetweenRequestsInS
        if (fakeSNI.isEmpty) {
#if DEBUG
            print("Invalid fake SNI. Set google.com")
#endif
            self.fakeSNI = "google.com"
        } else {
            self.fakeSNI = fakeSNI
        }
        self.domainListIDs = Set(domainListIDs)
        self.strategyListIDs = Set(strategyListIDs)
    }
    
    public init(source: SBDTestConfig) {
        self.domainRequestsCount = source.domainRequestsCount
        self.parallelRequestsCount = source.parallelRequestsCount
        self.domainAnswerTimeoutInS = source.domainAnswerTimeoutInS
        self.delayBetweenRequestsInS = source.delayBetweenRequestsInS
        self.fakeSNI = source.fakeSNI
        self.domainListIDs = Set(source.domainListIDs)
        self.strategyListIDs = Set(source.strategyListIDs)
        self.listenPort = source.listenPort
    }
    
    /// Retrieve custom strategies details by used IDs and raw strategy list array
    public func retrieveStrategies(strategyLists: [SBDStrategyList]) -> Set<SBDStrategy> {
        var res = Set<SBDStrategy>()
        for list in strategyLists {
            if (!strategyListIDs.contains(list.id)) {
                continue
            }
            for strategy in list.strategies {
                if (res.contains(strategy)) {
                    continue
                }
                let sniAppliedStrategy = SBDTestConfig.applySNIForStrategy(fakeSNI, strategy: strategy)
                if (res.contains(sniAppliedStrategy)) {
                    continue
                }
                res.insert(sniAppliedStrategy)
            }
        }
        return res
    }
    
    /// Retrieve domains by used IDs and raw domain list array
    public func retrieveDomains(domainLists: [SBDDomainList]) -> Set<String> {
        var res = Set<String>()
        for list in domainLists {
            if (!domainListIDs.contains(list.id)) {
                continue
            }
            for domain in list.domains {
                if (res.contains(domain)) {
                    continue
                }
                res.insert(domain)
            }
        }
        return res
    }
    
    public func copyWith(domainRequestsCount: UInt8? = nil, parallelRequestsCount: UInt8? = nil, domainAnswerTimeoutInS: UInt8? = nil, delayBetweenRequestsInS: UInt8? = nil, fakeSNI: String? = nil, domainListIDs: Set<String>? = nil, strategyListIDs: Set<String>? = nil, listenPort: UInt16? = nil) -> SBDTestConfig {
        return SBDTestConfig(domainRequestsCount: domainRequestsCount ?? self.domainRequestsCount, parallelRequestsCount: parallelRequestsCount ?? self.parallelRequestsCount, domainAnswerTimeoutInS: domainAnswerTimeoutInS ?? self.domainAnswerTimeoutInS, delayBetweenRequestsInS: delayBetweenRequestsInS ?? self.delayBetweenRequestsInS, fakeSNI: fakeSNI ?? self.fakeSNI, domainListIDs: domainListIDs ?? self.domainListIDs, strategyListIDs: strategyListIDs ?? self.strategyListIDs, listenPort: listenPort ?? self.listenPort)
    }
    
    /// Replacing {sni} cmd arg to defined value (romanvht/byedpi strategies adaptation)
    public static func applySNIForStrategy(_ sni: String, strategy: SBDStrategy) -> SBDStrategy {
        if (sni.isEmpty) {
            return strategy
        }
        let argsSet = Set<String>(strategy.cmdArgs)
        if (!argsSet.contains("{sni}")) {
            return strategy
        }
        var out: [String] = [String].init(strategy.cmdArgs)
        var i = 0
        while i < out.count {
            let t = out[i]
            if (t != "{sni}") {
                i += 1
                continue
            }
            out[i] = sni
            break
        }
        return SBDStrategy(cmdArgs: out)
    }
}
