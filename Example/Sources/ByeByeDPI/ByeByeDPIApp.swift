//
//  ByeDPIApp.swift
//  ByeByeDPI
//
//  Created by developer on 24.02.2026.
//

import SwiftUI
import SwByeDPI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(WidgetKit)
import WidgetKit
#endif

#if DEBUG
let previewProperties = AppProperties()
let previewLnwPermissionManager = LNWPermissionManager()
let previewDomainsManager = DomainsManager(lists: [
    BookTestDomains.domainsList,
    GoogleVideoTestDomains.domainsList,
    InstagramTestDomains.domainsList,
    YouTubeTestDomains.domainsList,
])
let previewStrategiesManager = StrategiesManager(lists: [
    BuiltInDPIeStrategies.strategiesList
])
let previewByeDPIManager = ByeDPIManager()
let previewTestManager = TestManager()
let previewNeManager = NEObservableManager { _, _ in }
let previewCatalogStore = OnlineStrategyCatalogStore()
let previewStrategyLibrary = StrategyLibraryStore()
let previewDiagnosticsMonitor = ServiceDiagnosticsMonitor()
let previewNetworkMonitor = NetworkEnvironmentMonitor()
let previewAutomationManager = StrategyAutomationManager(
    properties: previewProperties,
    neManager: previewNeManager,
    catalog: previewCatalogStore,
    library: previewStrategyLibrary,
    diagnostics: previewDiagnosticsMonitor,
    network: previewNetworkMonitor
)
#endif

@main
struct ByeByeDPIApp: App {
    
    @StateObject fileprivate var appProps: AppProperties
    @StateObject fileprivate var lnwPermissionManager: LNWPermissionManager
    @StateObject fileprivate var domainsManager: DomainsManager
    @StateObject fileprivate var strategiesManager: StrategiesManager
    @StateObject fileprivate var byeDPIManager: ByeDPIManager
    @StateObject fileprivate var neManager: NEObservableManager
    @StateObject fileprivate var testManager: TestManager
    @StateObject fileprivate var catalogStore: OnlineStrategyCatalogStore
    @StateObject fileprivate var strategyLibrary: StrategyLibraryStore
    @StateObject fileprivate var diagnosticsMonitor: ServiceDiagnosticsMonitor
    @StateObject fileprivate var networkMonitor: NetworkEnvironmentMonitor
    @StateObject fileprivate var automationManager: StrategyAutomationManager
    
    init() {
#if canImport(UIKit)
        let navigationAppearance = UINavigationBarAppearance()
        navigationAppearance.configureWithTransparentBackground()
        navigationAppearance.backgroundColor = .clear
        navigationAppearance.shadowColor = .clear
        navigationAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        navigationAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance = navigationAppearance
        UINavigationBar.appearance().compactAppearance = navigationAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navigationAppearance
#endif

        //App Delegate launch analogue
        let props = AppProperties.load()
        _appProps = StateObject(wrappedValue: props)
        _lnwPermissionManager = StateObject(wrappedValue: LNWPermissionManager())
        let domainsMngr = DomainsManager()
        if (domainsMngr.lists.isEmpty) {
            //Define default lists for empty manager
            domainsMngr.controller.addListItems([
                //Domains for strategy tests
                BookTestDomains.domainsList,
                CloudflareTestDomains.domainsList,
                DiscordTestDomains.domainsList,
                FacebookTestDomains.domainsList,
                GoogleVideoTestDomains.domainsList,
                GoogleAiTestDomains.domainsList,
                GoogleMeetTestDomains.domainsList,
                GooglePlayTestDomains.domainsList,
                InstagramTestDomains.domainsList,
                LinkedInTestDomains.domainsList,
                MiscTestDomains.domainsList,
                RobloxTestDomains.domainsList,
                SocialTestDomains.domainsList,
                SoundCloudTestDomains.domainsList,
                SteamTestDomains.domainsList,
                SuperCellTestDomains.domainsList,
                TelegramTestDomains.domainsList,
                TikTokTestDomains.domainsList,
                TorrentTestDomains.domainsList,
                TorTestDomains.domainsList,
                TwitchTestDomains.domainsList,
                TwitterTestDomains.domainsList,
                VideoTestDomains.domainsList,
                WhatsappTestDomains.domainsList,
                YouTubeTestDomains.domainsList,
                FacebookShortTestDomains.domainsList,
                InstagramShortTestDomains.domainsList,
                TwitterShortTestDomains.domainsList,
                VideoShortTestDomains.domainsList,
                WhatsappShortTestDomains.domainsList,
                
                //Filter --hosts (black lists  for ByeDPI)
                AlfaBankDPIBypassSLD.domainsList,
                GazpromDPIBypassSLD.domainsList,
                GitDPIBypassSLD.domainsList,
                GovDPIBypassSLD.domainsList,
                MAXDPIBypassSLD.domainsList,
                MiscDPIBypassSLD.domainsList,
                NewsDPIBypassSLD.domainsList,
                SberDPIBypassSLD.domainsList,
                TBankDPIBypassSLD.domainsList,
                TwoGISDPIBypassSLD.domainsList,
                VKDPIBypassSLD.domainsList,
                VTBDPIBypassSLD.domainsList,
                YandexDPIBypassSLD.domainsList,
            ])
        }
        _domainsManager = StateObject(wrappedValue: domainsMngr)
        let strategiesMngr = StrategiesManager()
        if (strategiesMngr.lists.isEmpty) {
            //Define built-in strategies for empty manager
            strategiesMngr.controller.addListItems([
                BuiltInDPIeStrategies.strategiesList,
                ExternalDPIeStrategies.strategiesList,
            ])
        }
        _strategiesManager = StateObject(wrappedValue: strategiesMngr)
        _byeDPIManager = StateObject(wrappedValue: ByeDPIManager())
        let neMngr = NEObservableManager(initCompletion: { _, _ in })
        _neManager = StateObject(wrappedValue: neMngr)
        _testManager = StateObject(wrappedValue: TestManager())
        let catalog = OnlineStrategyCatalogStore()
        let library = StrategyLibraryStore()
        let diagnostics = ServiceDiagnosticsMonitor()
        let network = NetworkEnvironmentMonitor()
        _catalogStore = StateObject(wrappedValue: catalog)
        _strategyLibrary = StateObject(wrappedValue: library)
        _diagnosticsMonitor = StateObject(wrappedValue: diagnostics)
        _networkMonitor = StateObject(wrappedValue: network)
        _automationManager = StateObject(wrappedValue: StrategyAutomationManager(
            properties: props,
            neManager: neMngr,
            catalog: catalog,
            library: library,
            diagnostics: diagnostics,
            network: network
        ))
        catalog.load()
    }
    
    var body: some Scene {
        WindowGroup {
            NavigationView {
                HomeScreen()
            }
            .accentColor(PalkaDesign.textPrimary)
            .preferredColorScheme(.dark)
            .environmentObject(appProps)
            .environmentObject(lnwPermissionManager)
            .environmentObject(domainsManager)
            .environmentObject(strategiesManager)
            .environmentObject(byeDPIManager)
            .environmentObject(neManager)
            .environmentObject(testManager)
            .environmentObject(catalogStore)
            .environmentObject(strategyLibrary)
            .environmentObject(diagnosticsMonitor)
            .environmentObject(networkMonitor)
            .environmentObject(automationManager)
            .onOpenURL { url in
                guard url.scheme == "palkadpi", url.host == "toggle" else { return }
                if neManager.vpnRunning {
                    neManager.stopConnection()
                } else {
                    neManager.startConnection { _, _ in }
                }
            }
            .onChange(of: neManager.vpnRunning) { _ in
#if canImport(WidgetKit)
                WidgetCenter.shared.reloadAllTimelines()
#endif
            }
            .onChange(of: networkMonitor.kind) { networkKind in
                guard networkKind != .offline,
                      appProps.networkProfiles.contains(where: { $0.networkKind == networkKind }) else {
                    return
                }
                let reconnect = neManager.vpnRunning
                if reconnect {
                    neManager.stopConnection()
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + (reconnect ? 1.0 : 0.0)) {
                    guard appProps.applyNetworkProfile(for: networkKind) else { return }
                    if reconnect {
                        neManager.startConnection { _, _ in }
                    }
                }
            }
        }
    }
}
