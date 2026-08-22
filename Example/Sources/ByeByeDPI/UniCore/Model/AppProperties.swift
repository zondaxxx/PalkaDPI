//
//  AppProperties.swift
//  SwByeDPI
//
//  Created by Developer on 21.02.2026.
//

import Foundation
import SwByeDPI

class AppProperties: Codable, ObservableObject
{
    //dns comss: IPV4 - 83.220.169.155, 195.133.25.16; IPV6 - 2a03:6f00:a::3f24 и 2a03:6f00:a::2944; https://dns.comss.one/dns-query
    fileprivate static let _defaultDoH = "https://dns.comss.one/dns-query"
    fileprivate static let _defaultResolvedDnsServers = ["83.220.169.155", "195.133.25.16"]
    fileprivate static let _plistFilename = Constants.PSEUDO_BUNDLE_ID
    
    @Published var byeDPILaunchConfig: SBDConfig {
        willSet {
            UserDefaultsAppProperties.byeDPIListenIp = newValue.listenIP
            UserDefaultsAppProperties.byeDPIListenPort = newValue.listenPort
            UserDefaultsAppProperties.byeDPIBufSize = newValue.bufSize
            UserDefaultsAppProperties.byeDPIMaxConn = newValue.maxConn
            UserDefaultsAppProperties.byeDPITTL = newValue.ttl
            UserDefaultsAppProperties.byeDPIRestrictDomainResolve = newValue.noDomain
            UserDefaultsAppProperties.byeDPIRestrictUDP = newValue.noUDP
            UserDefaultsAppProperties.byeDPILogLevel = newValue.logLevelRaw
            UserDefaultsAppProperties.byeDPICmdArgs = newValue.args
            let cmdLine = newValue.cmdArgs.joined(separator: " ")
            if (_byeDPICmdEditorHistorySet.contains(cmdLine)) {
                for i in 0..<byeDPICmdEditorHistory.count {
                    if (byeDPICmdEditorHistory[i] != cmdLine) {
                        continue
                    }
                    byeDPICmdEditorHistory.remove(at: i)
                    break
                }
            } else {
                _byeDPICmdEditorHistorySet.insert(cmdLine)
            }
            byeDPICmdEditorHistory.insert(cmdLine, at: 0)
        }
    }
    
    @Published var byeDPITestConfig: SBDTestConfig
    
    @Published fileprivate(set) var byeDPICmdEditorHistory: [String]
    fileprivate var _byeDPICmdEditorHistorySet: Set<String>
    var byeDPICmdEditorHistorySet: Set<String> {
        get {
            return Set<String>(byeDPICmdEditorHistory)
        }
    }
    
    @Published var byeDPIDomainListsIDsBypass: Set<String>
    
    @Published var dnsOverAddr: String {
        didSet {
            UserDefaultsAppProperties.dnsOverAddr = dnsOverAddr
        }
    }
    
    @Published var resolvedDnsServers: [String] {
        didSet {
            UserDefaultsAppProperties.resolvedDnsServers = resolvedDnsServers
        }
    }
    
    @Published var tunMtu: UInt16 {
        didSet {
            UserDefaultsAppProperties.tunMtu = tunMtu
        }
    }

    /// Kept outside the Codable payload so existing saved settings remain
    /// compatible when strategy catalog support is added.
    var activeStrategyName: String {
        get {
            return UserDefaultsAppProperties.activeStrategyName
        }
        set {
            objectWillChange.send()
            UserDefaultsAppProperties.activeStrategyName = newValue
        }
    }

    var activeStrategyID: String {
        get {
            return UserDefaultsAppProperties.activeStrategyID
        }
        set {
            objectWillChange.send()
            UserDefaultsAppProperties.activeStrategyID = newValue
        }
    }

    var selectedServiceIDs: [String] {
        get { UserDefaultsAppProperties.selectedServiceIDs }
        set {
            objectWillChange.send()
            let validIDs = Set(PalkaService.all.map(\.id))
            let filtered = newValue.filter { validIDs.contains($0) }
            UserDefaultsAppProperties.selectedServiceIDs = filtered.isEmpty
                ? PalkaService.defaultIDs
                : filtered
            reapplyActiveTemplate()
        }
    }

    var customServiceDomains: [String] {
        get { UserDefaultsAppProperties.customServiceDomains }
        set {
            objectWillChange.send()
            UserDefaultsAppProperties.customServiceDomains = newValue
            reapplyActiveTemplate()
        }
    }

    var smartRecoveryEnabled: Bool {
        get { UserDefaultsAppProperties.smartRecoveryEnabled }
        set {
            objectWillChange.send()
            UserDefaultsAppProperties.smartRecoveryEnabled = newValue
        }
    }

    var onDemandEnabled: Bool {
        get { UserDefaultsAppProperties.onDemandEnabled }
        set {
            objectWillChange.send()
            UserDefaultsAppProperties.onDemandEnabled = newValue
        }
    }

    var onDemandWiFiEnabled: Bool {
        get { UserDefaultsAppProperties.onDemandWiFiEnabled }
        set {
            objectWillChange.send()
            UserDefaultsAppProperties.onDemandWiFiEnabled = newValue
        }
    }

    var onDemandCellularEnabled: Bool {
        get { UserDefaultsAppProperties.onDemandCellularEnabled }
        set {
            objectWillChange.send()
            UserDefaultsAppProperties.onDemandCellularEnabled = newValue
        }
    }

    var networkProfiles: [PalkaNetworkProfile] {
        get { UserDefaultsAppProperties.networkProfiles }
        set {
            objectWillChange.send()
            UserDefaultsAppProperties.networkProfiles = newValue
        }
    }
    
#if DEBUG
    init() {
        byeDPILaunchConfig = SBDConfig(commandArgs: PalkaPreset.recommendedCommandArgs)
        byeDPITestConfig = SBDTestConfig(domainRequestsCount: 2, parallelRequestsCount: 5, domainAnswerTimeoutInS: 3, delayBetweenRequestsInS: 1, fakeSNI: "google.com", domainListIDs: Set(), strategyListIDs: Set())
        byeDPICmdEditorHistory = [
            SBDConfig(commandArgs: PalkaPreset.recommendedCommandArgs).cmdArgs.joined(separator: " "),
            SBDConfig(commandArgs: ["-n", "google.com", "-d1", "-s1+s", "-r1+s", "-e1", "-m1", "-o1+s", "-t2", "-a1"]).cmdArgs.joined(separator: " ")
        ]
        _byeDPICmdEditorHistorySet = Set<String>([
            SBDConfig(commandArgs: PalkaPreset.recommendedCommandArgs).cmdArgs.joined(separator: " "),
            SBDConfig(commandArgs: ["-n", "google.com", "-d1", "-s1+s", "-r1+s", "-e1", "-m1", "-o1+s", "-t2", "-a1"]).cmdArgs.joined(separator: " ")
        ])
        byeDPIDomainListsIDsBypass = [
            YandexDPIBypassSLD.domainsList.id
        ]
        resolvedDnsServers = AppProperties._defaultResolvedDnsServers
        dnsOverAddr = AppProperties._defaultDoH
        tunMtu = 1500
    }
#endif
    
    init(byeDPILaunchConfig: SBDConfig, byeDPITestConfig: SBDTestConfig, byeDPICmdEditorHistory: [String], byeDPIDomainListsIDsBypass: Set<String>, resolvedDnsServers: [String], dnsOverAddr: String, tunMtu: UInt16)
    {
        self.byeDPILaunchConfig = byeDPILaunchConfig
        self.byeDPITestConfig = byeDPITestConfig
        self.byeDPICmdEditorHistory = byeDPICmdEditorHistory
        self._byeDPICmdEditorHistorySet = Set<String>(byeDPICmdEditorHistory)
        self.byeDPIDomainListsIDsBypass = byeDPIDomainListsIDsBypass
        self.resolvedDnsServers = resolvedDnsServers
        self.dnsOverAddr = dnsOverAddr
        self.tunMtu = tunMtu
    }
    
    func removeRecentCmd(at index: Int) -> String? {
        if (index < 0 || index >= byeDPICmdEditorHistory.count) {
            return nil
        }
        return byeDPICmdEditorHistory.remove(at: index)
    }
    
    ///Save application properties
    func save()
    {
        if (PlistUtil.savePropertyList(self, filename: AppProperties._plistFilename)) {
            return
        }
#if DEBUG
            print("Application properties not saved")
#endif
    }
    
    ///Load application properties with specific filename
    class func load() -> AppProperties
    {
        if let loadedProperties: AppProperties = PlistUtil.parsePropertyList(filename: AppProperties._plistFilename)
        {
            syncUserDefaults(properties: loadedProperties)
            loadedProperties.migrateObsoletePalkaStrategyIfNeeded()
            return loadedProperties
        }
        let cpuCores = UInt8(ProcessInfo.processInfo.processorCount)
        let properties = AppProperties(byeDPILaunchConfig: SBDConfig(commandArgs: PalkaPreset.recommendedCommandArgs), byeDPITestConfig: SBDTestConfig(domainRequestsCount: 2, parallelRequestsCount: cpuCores * 2, domainAnswerTimeoutInS: 5, delayBetweenRequestsInS: 1, fakeSNI: "google.com", domainListIDs: Set<String>([
            DiscordTestDomains.domainsList.id,
            YouTubeTestDomains.domainsList.id,
            GoogleVideoTestDomains.domainsList.id
        ]), strategyListIDs: Set<String>([
            BuiltInDPIeStrategies.strategiesList.id
        ])), byeDPICmdEditorHistory: [], byeDPIDomainListsIDsBypass: [
            AlfaBankDPIBypassSLD.domainsList.id,
            GazpromDPIBypassSLD.domainsList.id,
            GitDPIBypassSLD.domainsList.id,
            GovDPIBypassSLD.domainsList.id,
            MAXDPIBypassSLD.domainsList.id,
            MiscDPIBypassSLD.domainsList.id,
            NewsDPIBypassSLD.domainsList.id,
            SberDPIBypassSLD.domainsList.id,
            TBankDPIBypassSLD.domainsList.id,
            TwoGISDPIBypassSLD.domainsList.id,
            VKDPIBypassSLD.domainsList.id,
            VTBDPIBypassSLD.domainsList.id,
            YandexDPIBypassSLD.domainsList.id,
        ], resolvedDnsServers: AppProperties._defaultResolvedDnsServers, dnsOverAddr: AppProperties._defaultDoH, tunMtu: 1500)
        properties.save()
        syncUserDefaults(properties: properties)
        return properties
    }

    /// Restores the shipping Discord + YouTube preset while preserving proxy
    /// address, buffer, connection, TTL, and logging preferences.
    func applyRecommendedPreset() {
        byeDPILaunchConfig = byeDPILaunchConfig.copyWith(
            commandArgs: PalkaPreset.resolve(
                template: PalkaPreset.recommendedTemplateArgs,
                serviceIDs: selectedServiceIDs,
                customDomains: customServiceDomains
            )
        )
        activeStrategyName = PalkaPreset.name
        activeStrategyID = PalkaPreset.id
        UserDefaultsAppProperties.activeStrategyTemplateArgs = PalkaPreset.recommendedTemplateArgs
        save()
    }

    /// Applies an already validated catalog strategy while preserving local
    /// proxy, DNS, buffer, logging, and tunnel settings.
    func applyCatalogStrategy(id: String, name: String, commandTemplate: [String]) {
        let resolved = PalkaPreset.resolve(
            template: commandTemplate,
            serviceIDs: selectedServiceIDs,
            customDomains: customServiceDomains
        )
        let validatedArgs = SBDConfig(commandArgs: resolved).validatedCmdArgs
        guard !validatedArgs.isEmpty else { return }

        byeDPILaunchConfig = byeDPILaunchConfig.copyWith(commandArgs: validatedArgs)
        activeStrategyName = name
        activeStrategyID = id
        UserDefaultsAppProperties.activeStrategyTemplateArgs = commandTemplate
        save()
    }

    func applyCustomStrategy(name: String, commandArgs: [String]) {
        let validatedArgs = SBDConfig(commandArgs: commandArgs).validatedCmdArgs
        guard !validatedArgs.isEmpty else { return }

        byeDPILaunchConfig = byeDPILaunchConfig.copyWith(commandArgs: validatedArgs)
        activeStrategyName = name
        activeStrategyID = "custom"
        UserDefaultsAppProperties.activeStrategyTemplateArgs = []
        save()
    }

    func saveCurrentStrategy(for networkKind: PalkaNetworkKind) {
        guard networkKind != .offline else { return }
        let profile = PalkaNetworkProfile(
            networkKind: networkKind,
            strategyID: activeStrategyID,
            strategyName: activeStrategyName,
            commandTemplate: UserDefaultsAppProperties.activeStrategyTemplateArgs
        )
        var profiles = networkProfiles.filter { $0.networkKind != networkKind }
        profiles.append(profile)
        networkProfiles = profiles
    }

    @discardableResult
    func applyNetworkProfile(for networkKind: PalkaNetworkKind) -> Bool {
        guard let profile = networkProfiles.first(where: { $0.networkKind == networkKind }),
              !profile.commandTemplate.isEmpty else { return false }
        applyCatalogStrategy(
            id: profile.strategyID,
            name: profile.strategyName,
            commandTemplate: profile.commandTemplate
        )
        return true
    }

    private func reapplyActiveTemplate() {
        let template = UserDefaultsAppProperties.activeStrategyTemplateArgs
        guard !template.isEmpty else { return }
        let resolved = PalkaPreset.resolve(
            template: template,
            serviceIDs: selectedServiceIDs,
            customDomains: customServiceDomains
        )
        let validatedArgs = SBDConfig(commandArgs: resolved).validatedCmdArgs
        guard !validatedArgs.isEmpty else { return }
        byeDPILaunchConfig = byeDPILaunchConfig.copyWith(commandArgs: validatedArgs)
        save()
    }

    private func migrateObsoletePalkaStrategyIfNeeded() {
        let obsoleteIDs: Set<String> = [
            "builtin.recommended",
            "palka.balanced.v1",
            "palka.light-split.v1",
            "palka.tls-record.v1",
            "palka.multisplit.v1",
            "palka.reorder.v1",
            "palka.discord-voice.v1",
            "palka.ios.disorder-record.v2",
            "palka.ios.oob-record.v2",
            "palka.ios.alternating-multisplit.v2",
            "palka.ios.disoob-chain.v2",
            "palka.ios.disoob-short.v2",
            "palka.ios.record-disoob.v2",
            "palka.ios.oob-basic.v2",
            "palka.ios.multisplit-quic.v2",
            "palka.ios.oob-quic.v2",
            "palka.ios.disorder-quic.v2",
        ]
        guard obsoleteIDs.contains(activeStrategyID) else { return }
        applyRecommendedPreset()
    }
    
    fileprivate class func syncUserDefaults(properties: AppProperties) {
        UserDefaultsAppProperties.byeDPIListenIp = properties.byeDPILaunchConfig.listenIP
        UserDefaultsAppProperties.byeDPIListenPort = properties.byeDPILaunchConfig.listenPort
        UserDefaultsAppProperties.byeDPIBufSize = properties.byeDPILaunchConfig.bufSize
        UserDefaultsAppProperties.byeDPITTL = properties.byeDPILaunchConfig.ttl
        UserDefaultsAppProperties.byeDPIRestrictDomainResolve = properties.byeDPILaunchConfig.noDomain
        UserDefaultsAppProperties.byeDPIRestrictUDP = properties.byeDPILaunchConfig.noUDP
        UserDefaultsAppProperties.byeDPILogLevel = properties.byeDPILaunchConfig.logLevelRaw
        UserDefaultsAppProperties.byeDPICmdArgs = properties.byeDPILaunchConfig.args
        UserDefaultsAppProperties.dnsOverAddr = properties.dnsOverAddr
        UserDefaultsAppProperties.resolvedDnsServers = properties.resolvedDnsServers
        UserDefaultsAppProperties.tunMtu = properties.tunMtu
    }
}
