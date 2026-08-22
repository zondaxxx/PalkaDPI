//
//  SettingsScreen.swift
//  PalkaDPI
//

import SwiftUI
import SwByeDPI

/// The short settings route intended for most people. Diagnostic tools and
/// raw network parameters live one level deeper in AdvancedSettingsScreen.
struct SettingsScreen: View {
    @EnvironmentObject private var properties: AppProperties

    @State private var presetApplied = false

    var body: some View {
        ZStack {
            PalkaBackground()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: PalkaDesign.sectionSpacing) {
                    settingsHeader
                        .palkaEntrance()
                    quickSetupSection
                        .palkaEntrance(delay: 0.05)
                    strategySection
                        .palkaEntrance(delay: 0.10)
                    connectionAutomationSection
                        .palkaEntrance(delay: 0.15)
                    advancedSection
                        .palkaEntrance(delay: 0.20)
                    aboutSection
                        .palkaEntrance(delay: 0.25)
                }
                .padding(.horizontal, PalkaDesign.screenPadding)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
        }
        .foregroundColor(PalkaDesign.textPrimary)
        .navigationTitle(R.string.localizable.generalSettings())
#if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
    }

    private var settingsHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(palkaLocalized("palkaSimpleSettingsTitle"))
                .font(.system(size: 28, weight: .heavy))
                .tracking(-0.85)

            Text(palkaLocalized("palkaSimpleSettingsDescription"))
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(PalkaDesign.textSecondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var quickSetupSection: some View {
        PalkaSettingsSection(palkaLocalized("palkaQuickSetupSection")) {
            NavigationLink(destination: AutomationScreen()) {
                SettingsStaticInfoView(
                    title: palkaLocalized("palkaAutoTitle"),
                    text: palkaLocalized("palkaAutoSettingsDescription"),
                    leadingIcon: Image(systemName: "wand.and.stars")
                )
            }
            .buttonStyle(PalkaPressButtonStyle())

            SettingsButtonView(
                title: R.string.localizable.palkaApplyPreset(),
                text: R.string.localizable.palkaApplyPresetDescription(),
                leadingIcon: Image(R.image.icCheck)
            ) {
                properties.applyRecommendedPreset()
                withAnimation(.easeOut(duration: 0.18)) {
                    presetApplied = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
                    withAnimation(.easeOut(duration: 0.18)) {
                        presetApplied = false
                    }
                }
            }

            if presetApplied {
                PalkaFeedbackBanner(
                    text: palkaLocalized("palkaPresetApplied"),
                    kind: .success
                )
                .transition(.opacity)
            }
        }
    }

    private var strategySection: some View {
        PalkaSettingsSection(palkaLocalized("palkaStrategiesSection")) {
            NavigationLink(destination: ServiceSelectionScreen()) {
                SettingsStaticInfoView(
                    title: palkaLocalized("palkaServicesTitle"),
                    text: PalkaService.selected(from: properties.selectedServiceIDs)
                        .map(\.name)
                        .joined(separator: ", "),
                    leadingIcon: Image(systemName: "square.grid.2x2")
                )
            }
            .buttonStyle(PalkaPressButtonStyle())

            NavigationLink(destination: OnlineStrategyCatalogScreen()) {
                SettingsStaticInfoView(
                    title: palkaLocalized("palkaCatalogTitle"),
                    text: String(
                        format: palkaLocalized("palkaCurrentStrategyFormat"),
                        properties.activeStrategyName
                    ),
                    leadingIcon: Image(systemName: "icloud.and.arrow.down")
                )
            }
            .buttonStyle(PalkaPressButtonStyle())

            NavigationLink(destination: StrategyHistoryScreen()) {
                SettingsStaticInfoView(
                    title: palkaLocalized("palkaHistoryTitle"),
                    text: palkaLocalized("palkaHistorySettingsDescription"),
                    leadingIcon: Image(systemName: "clock.arrow.circlepath")
                )
            }
            .buttonStyle(PalkaPressButtonStyle())
        }
    }

    private var connectionAutomationSection: some View {
        PalkaSettingsSection(palkaLocalized("palkaConnectionSection")) {
            NavigationLink(destination: DiagnosticsScreen()) {
                SettingsStaticInfoView(
                    title: palkaLocalized("palkaDiagnosticsTitle"),
                    text: palkaLocalized("palkaDiagnosticsSettingsDescription"),
                    leadingIcon: Image(systemName: "stethoscope")
                )
            }
            .buttonStyle(PalkaPressButtonStyle())

            NavigationLink(destination: NetworkProfilesScreen()) {
                SettingsStaticInfoView(
                    title: palkaLocalized("palkaNetworkProfilesTitle"),
                    text: palkaLocalized("palkaNetworkProfilesSettingsDescription"),
                    leadingIcon: Image(systemName: "network")
                )
            }
            .buttonStyle(PalkaPressButtonStyle())
        }
    }

    private var advancedSection: some View {
        PalkaSettingsSection(palkaLocalized("palkaAdvancedSection")) {
            NavigationLink(destination: AdvancedSettingsScreen()) {
                SettingsStaticInfoView(
                    title: palkaLocalized("palkaAdvancedSettings"),
                    text: palkaLocalized("palkaAdvancedSettingsDescription"),
                    leadingIcon: Image(systemName: "wrench.and.screwdriver")
                )
            }
            .buttonStyle(PalkaPressButtonStyle())
        }
    }

    private var aboutSection: some View {
        PalkaSettingsSection(R.string.localizable.settingsAboutSecton()) {
            Link(destination: URL(string: Constants.sourceCodeLink)!) {
                SettingsStaticInfoView(
                    title: R.string.localizable.settingsAboutSourceCode(),
                    text: "GitHub",
                    leadingIcon: Image(R.image.icGithub)
                )
            }
            .buttonStyle(PalkaPressButtonStyle())

            Link(destination: URL(string: Constants.acknowledgementsLink)!) {
                SettingsStaticInfoView(
                    title: palkaLocalized("palkaAcknowledgements"),
                    text: palkaLocalized("palkaAcknowledgementsDescription"),
                    leadingIcon: Image(systemName: "heart")
                )
            }
            .buttonStyle(PalkaPressButtonStyle())

            SettingsStaticInfoView(
                title: R.string.localizable.settingsAboutAppVersionCode(),
                text: Constants.PSEUDO_BUNDLE_VERSION,
                leadingIcon: Image(R.image.icInfo),
                showsDisclosure: false
            )
        }
    }
}

struct AdvancedSettingsScreen: View {
    @EnvironmentObject private var properties: AppProperties
    @EnvironmentObject private var domainsManager: DomainsManager

    @State private var dnsOverAddr = ""
    @State private var resolvedDnsServers = ""
    @State private var ipAddr = ""
    @State private var port = ""
    @State private var bufSize = ""
    @State private var showShareActivityVC = false

    private var exportFileURL: URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("palkadpi-config.json", isDirectory: false)
    }

    var body: some View {
        ZStack {
            PalkaBackground()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: PalkaDesign.sectionSpacing) {
                    advancedHeader
                        .palkaEntrance()
                    connectionSection
                        .palkaEntrance(delay: 0.05)
                    toolsSection
                        .palkaEntrance(delay: 0.10)
                    proxySection
                        .palkaEntrance(delay: 0.15)
                }
                .padding(.horizontal, PalkaDesign.screenPadding)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
        }
        .foregroundColor(PalkaDesign.textPrimary)
        .onAppear(perform: loadValues)
        .onDisappear {
            try? FileManager.default.removeItem(at: exportFileURL)
        }
#if canImport(UIKit) && !os(tvOS)
        .sheet(isPresented: $showShareActivityVC, onDismiss: {
            showShareActivityVC = false
            try? FileManager.default.removeItem(at: exportFileURL)
        }, content: {
            ActivityVC(presented: $showShareActivityVC, activityItems: [exportFileURL])
                .ignoresSafeArea(.all, edges: .bottom)
        })
#endif
        .navigationTitle(palkaLocalized("palkaAdvancedSettings"))
#if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
    }

    private var advancedHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(palkaLocalized("palkaExpertTitle"))
                .font(.system(size: 28, weight: .heavy))
                .tracking(-0.85)

            Text(palkaLocalized("palkaExpertDescription"))
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(PalkaDesign.textSecondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var connectionSection: some View {
        PalkaSettingsSection(R.string.localizable.settingsGeneralSection()) {
            SettingsEditableInfoView(
                title: R.string.localizable.settingsGeneralDNSOption(),
                value: $dnsOverAddr,
                leadingIcon: Image(R.image.icWorld),
                validator: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty },
                onNewValue: { newValue in
                    guard properties.dnsOverAddr != newValue else { return }
                    dnsOverAddr = newValue
                    properties.dnsOverAddr = newValue
                    properties.save()
                },
                keyboardType: .URL,
                autocapitalizationType: .none
            )

            SettingsEditableInfoView(
                title: R.string.localizable.settingsGeneralDNSResolvedOption(),
                value: $resolvedDnsServers,
                leadingIcon: Image(R.image.icWorld),
                validator: { input in
                    let servers = parseServers(input)
                    return !servers.isEmpty && servers.allSatisfy(isValidIPv4)
                },
                onNewValue: { newValue in
                    let servers = parseServers(newValue).filter(isValidIPv4)
                    let normalized = servers.joined(separator: " ")
                    guard properties.resolvedDnsServers != servers else { return }
                    resolvedDnsServers = normalized
                    properties.resolvedDnsServers = servers
                    properties.save()
                },
                keyboardType: .numbersAndPunctuation,
                autocapitalizationType: .none
            )

#if canImport(UIKit) && !os(tvOS)
            SettingsButtonView(
                title: R.string.localizable.settingsGeneralExportSettingsOption(),
                text: R.string.localizable.settingsGeneralExportSettingsOptionDesc(),
                leadingIcon: Image(R.image.icShare),
                onPressed: exportSettings
            )
#endif
        }
    }

    private var toolsSection: some View {
        PalkaSettingsSection(R.string.localizable.settingsByeDPISection()) {
            settingsLink(
                title: R.string.localizable.settingsByeDPIArgsOption(),
                text: R.string.localizable.settingsByeDPIArgsOptionDesc(),
                icon: Image(R.image.icCodeTags),
                destination: ByeDPICmdEditorScreen()
            )
            settingsLink(
                title: R.string.localizable.settingsDomainsListOption(),
                text: R.string.localizable.settingsDomainsListOptionDesc(),
                icon: Image(R.image.icList),
                destination: DomainListsScreen()
            )
            settingsLink(
                title: R.string.localizable.settingsStrategiesListOption(),
                text: R.string.localizable.settingsStrategiesListOptionDesc(),
                icon: Image(R.image.icGridHexagon),
                destination: StrategyListsScreen()
            )
            settingsLink(
                title: R.string.localizable.settingsByeDPIStrategyTestOption(),
                text: R.string.localizable.settingsByeDPIStrategyTestOptionDesc(),
                icon: Image(R.image.icSpeedometer),
                destination: ByeDPIStrategyTesterScreen()
            )
            settingsLink(
                title: R.string.localizable.settingsByeDPITestAnalyzerOption(),
                text: R.string.localizable.settingsByeDPITestAnalyzerOptionDesc(),
                icon: Image(R.image.icTool),
                destination: ByeDPITestResultsAnalyzerScreen()
            )
            settingsLink(
                title: R.string.localizable.settingsByeDPIDebugOption(),
                text: R.string.localizable.settingsByeDPIDebugOptionDesc(),
                icon: Image(R.image.icBracketsCheck),
                destination: ByeDPIStrategyDebuggerScreen(
                    initTestConfig: properties.byeDPITestConfig,
                    initStrategyCmdArgs: properties.byeDPILaunchConfig.cmdArgs
                )
            )
        }
    }

    private var proxySection: some View {
        PalkaSettingsSection(R.string.localizable.settingsByeDPIProxySection()) {
            SettingsEditableInfoView(
                title: R.string.localizable.settingsByeDPIProxyIpAddr(),
                value: $ipAddr,
                leadingIcon: Image(R.image.icWorld),
                validator: isValidIPv4,
                onNewValue: { newValue in
                    guard properties.byeDPILaunchConfig.listenIP != newValue else { return }
                    ipAddr = newValue
                    properties.byeDPILaunchConfig = properties.byeDPILaunchConfig.copyWith(listenIP: newValue)
                    properties.save()
                },
                keyboardType: .numbersAndPunctuation,
                autocapitalizationType: .none
            )

            SettingsEditableInfoView(
                title: R.string.localizable.settingsByeDPIProxyPort(),
                value: $port,
                leadingIcon: Image(R.image.icWorld),
                validator: { UInt16($0) != nil },
                onNewValue: { newValue in
                    guard let parsedNumber = UInt16(newValue),
                          properties.byeDPILaunchConfig.listenPort != parsedNumber else { return }
                    port = newValue
                    properties.byeDPILaunchConfig = properties.byeDPILaunchConfig.copyWith(listenPort: parsedNumber)
                    properties.save()
                },
                keyboardType: .numberPad,
                autocapitalizationType: .none
            )

            SettingsEditableInfoView(
                title: R.string.localizable.settingsByeDPIProxyBufSize(),
                value: $bufSize,
                leadingIcon: Image(R.image.icDb),
                validator: { input in
                    guard let parsedInput = UInt32(input) else { return false }
                    return parsedInput > 0
                },
                onNewValue: { newValue in
                    guard let parsedNumber = UInt32(newValue), parsedNumber > 0,
                          properties.byeDPILaunchConfig.bufSize != parsedNumber else { return }
                    bufSize = newValue
                    properties.byeDPILaunchConfig = properties.byeDPILaunchConfig.copyWith(bufSize: parsedNumber)
                    properties.save()
                },
                keyboardType: .numberPad,
                autocapitalizationType: .none
            )
        }
    }

    private func settingsLink<Destination: View>(
        title: String,
        text: String,
        icon: Image,
        destination: Destination
    ) -> some View {
        NavigationLink(destination: destination) {
            SettingsStaticInfoView(title: title, text: text, leadingIcon: icon)
        }
        .buttonStyle(PalkaPressButtonStyle())
    }

    private func loadValues() {
        dnsOverAddr = properties.dnsOverAddr
        resolvedDnsServers = properties.resolvedDnsServers.joined(separator: " ")
        ipAddr = properties.byeDPILaunchConfig.listenIP
        port = String(properties.byeDPILaunchConfig.listenPort)
        bufSize = String(properties.byeDPILaunchConfig.bufSize)
    }

    private func exportSettings() {
        guard !showShareActivityVC else { return }

        let config = SBDByeDPIAndroidConfig(
            dpiConfig: properties.byeDPILaunchConfig,
            domainLists: domainsManager.lists,
            testConfig: properties.byeDPITestConfig,
            apps: [],
            cmdHistory: properties.byeDPICmdEditorHistory,
            dnsIpAddr: properties.dnsOverAddr
        )

        do {
            let exportData = try JSONSerialization.data(withJSONObject: config.asExportDictionary())
            try exportData.write(to: exportFileURL)
            showShareActivityVC = true
        } catch {
            print(error)
        }
    }

    private func parseServers(_ input: String) -> [String] {
        input
            .split(whereSeparator: { $0.isWhitespace || $0 == "," })
            .map(String.init)
    }

    private func isValidIPv4(_ input: String) -> Bool {
        let octets = input.split(separator: ".", omittingEmptySubsequences: false)
        return octets.count == 4 && octets.allSatisfy { UInt8($0) != nil }
    }
}

#if DEBUG
#Preview {
    NavigationView {
        SettingsScreen()
    }
    .preferredColorScheme(.dark)
    .environmentObject(previewProperties)
    .environmentObject(previewDomainsManager)
    .environmentObject(previewStrategiesManager)
    .environmentObject(previewTestManager)
    .environmentObject(previewNeManager)
    .environmentObject(previewCatalogStore)
    .environmentObject(previewStrategyLibrary)
    .environmentObject(previewDiagnosticsMonitor)
    .environmentObject(previewNetworkMonitor)
    .environmentObject(previewAutomationManager)
}
#endif
