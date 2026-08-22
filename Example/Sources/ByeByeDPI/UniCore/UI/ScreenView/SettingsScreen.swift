//
//  SettingsScreen.swift
//  ByeByeDPI
//
//  Created by developer on 01.03.2026.
//

import SwiftUI
import SwByeDPI

struct SettingsScreen: View {
    
    @EnvironmentObject var properties: AppProperties
    @EnvironmentObject var domainsManager: DomainsManager
    
    @State fileprivate var dnsOverAddr = ""
    @State fileprivate var resolvedDnsServers = ""
    @State fileprivate var ipAddr = ""
    @State fileprivate var port = ""
    @State fileprivate var bufSize = ""
    
    @State fileprivate var showShareActivityVC = false
    
    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 8.0) {
                VStack(alignment: .leading) {
                    Text(R.string.localizable.settingsGeneralSection)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(Color(R.color.grSecondary))
                    //TODO language, theme
                    SettingsEditableInfoView(title: R.string.localizable.settingsGeneralDNSOption(), value: $dnsOverAddr, leadingIcon: Image(R.image.icWorld), validator: { input in
                        if (input.isEmpty) {
                            return false
                        }
                        return true
                    }, onNewValue: { newVal in
                        if (properties.dnsOverAddr == newVal) {
                            return
                        }
                        dnsOverAddr = newVal
                        properties.dnsOverAddr = newVal
                        properties.save()
                    }, keyboardType: .URL, autocapitalizationType: .none)
                    SettingsEditableInfoView(title: R.string.localizable.settingsGeneralDNSResolvedOption(), value: $resolvedDnsServers, leadingIcon: Image(R.image.icWorld), validator: { input in
                        if (input.isEmpty) {
                            return false
                        }
                        let splitted = input.split(separator: " ", omittingEmptySubsequences: true)
                        for split in splitted {
                            let innerSplitted = split.split(separator: ",", omittingEmptySubsequences: true)
                            for innerSplit in innerSplitted {
                                let ipAddrSplit = innerSplit.split(separator: ".")
                                if (ipAddrSplit.count != 4) {
                                    return false
                                }
                            }
                        }
                        return true
                    }, onNewValue: { newVal in
                        if (properties.resolvedDnsServers.joined(separator: " ") == newVal) {
                            return
                        }
                        var servers: [String] = []
                        let splitted = newVal.split(separator: " ", omittingEmptySubsequences: true)
                        for split in splitted {
                            let innerSplitted = split.split(separator: ",", omittingEmptySubsequences: true)
                            for innerSplit in innerSplitted {
                                let ipAddrSplit = innerSplit.split(separator: ".")
                                if (ipAddrSplit.count != 4) {
                                    continue
                                }
                                servers.append(String(innerSplit))
                            }
                        }
                        resolvedDnsServers = servers.joined(separator: " ")
                        properties.resolvedDnsServers = servers
                        properties.save()
                    }, keyboardType: .numbersAndPunctuation, autocapitalizationType: .none)
#if canImport(UIKit) && !os(tvOS)
                    /*SettingsButtonView(title: R.string.localizable.settingsGeneralImportSettingsOption(), text: R.string.localizable.settingsGeneralImportSettingsOptionDesc(), leadingIcon: Image(R.image.icDownload)) {
                        //TODO import settings via file picker
                    }*/
                    SettingsButtonView(title: R.string.localizable.settingsGeneralExportSettingsOption(), text: R.string.localizable.settingsGeneralExportSettingsOptionDesc(), leadingIcon: Image(R.image.icShare)) {
                        if (showShareActivityVC) {
                            return
                        }
                        let bbdConfig = SBDByeDPIAndroidConfig(dpiConfig: properties.byeDPILaunchConfig, domainLists: domainsManager.lists, testConfig: properties.byeDPITestConfig, apps: [], cmdHistory: properties.byeDPICmdEditorHistory, dnsIpAddr: properties.dnsOverAddr)
                        let tempDirUrl = FileManager.default.temporaryDirectory
                        let exportFileUrl = tempDirUrl.appendingPathComponent("bbdconfig.json", isDirectory: false)
                        do {
                            let exportData = try JSONSerialization.data(withJSONObject: bbdConfig.asExportDictionary())
                            try exportData.write(to: exportFileUrl)
                            showShareActivityVC = true
                        } catch {
                            print(error)
                            return
                        }
                    }
                    .sheet(isPresented: $showShareActivityVC, onDismiss: {
                        showShareActivityVC = false
                        let tempDirUrl = FileManager.default.temporaryDirectory
                        let exportFileUrl = tempDirUrl.appendingPathComponent("bbdconfig.json", isDirectory: false)
                        try? FileManager.default.removeItem(at: exportFileUrl)
                    }, content: {
                        let tempDirUrl = FileManager.default.temporaryDirectory
                        let exportFileUrl = tempDirUrl.appendingPathComponent("bbdconfig.json", isDirectory: false)
                        ActivityVC(presented: $showShareActivityVC, activityItems: [exportFileUrl])
                            .ignoresSafeArea(.all, edges: .bottom)
                    })
#endif
                }
                .padding(EdgeInsets(top: .zero, leading: .zero, bottom: 8.0, trailing: .zero))
                VStack(alignment: .leading) {
                    Text(R.string.localizable.settingsByeDPISection)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(Color(R.color.grSecondary))
                    SettingsButtonView(
                        title: R.string.localizable.palkaApplyPreset(),
                        text: R.string.localizable.palkaApplyPresetDescription(),
                        leadingIcon: Image(R.image.icCheck)
                    ) {
                        properties.applyRecommendedPreset()
                    }
                    NavigationLink {
                        ByeDPICmdEditorScreen()
                    } label: {
                        SettingsStaticInfoView(title: R.string.localizable.settingsByeDPIArgsOption(), text: R.string.localizable.settingsByeDPIArgsOptionDesc(), leadingIcon: Image(R.image.icCodeTags))
                    }
                    NavigationLink {
                        DomainListsScreen()
                    } label: {
                        SettingsStaticInfoView(title: R.string.localizable.settingsDomainsListOption(), text: R.string.localizable.settingsDomainsListOptionDesc(), leadingIcon: Image(R.image.icList))
                    }
                    NavigationLink {
                        StrategyListsScreen()
                    } label: {
                        SettingsStaticInfoView(title: R.string.localizable.settingsStrategiesListOption(), text: R.string.localizable.settingsStrategiesListOptionDesc(), leadingIcon: Image(R.image.icGridHexagon))
                    }
                    NavigationLink {
                        ByeDPIStrategyTesterScreen()
                    } label: {
                        SettingsStaticInfoView(title: R.string.localizable.settingsByeDPIStrategyTestOption(), text: R.string.localizable.settingsByeDPIStrategyTestOptionDesc(), leadingIcon: Image(R.image.icSpeedometer))
                    }
                    NavigationLink {
                        ByeDPITestResultsAnalyzerScreen()
                    } label: {
                        SettingsStaticInfoView(title: R.string.localizable.settingsByeDPITestAnalyzerOption(), text: R.string.localizable.settingsByeDPITestAnalyzerOptionDesc(), leadingIcon: Image(R.image.icTool))
                    }
                    NavigationLink {
                        ByeDPIStrategyDebuggerScreen(initTestConfig: properties.byeDPITestConfig, initStrategyCmdArgs: properties.byeDPILaunchConfig.cmdArgs)
                    } label: {
                        SettingsStaticInfoView(title: R.string.localizable.settingsByeDPIDebugOption(), text: R.string.localizable.settingsByeDPIDebugOptionDesc(), leadingIcon: Image(R.image.icBracketsCheck))
                    }
                }
                .padding(EdgeInsets(top: .zero, leading: .zero, bottom: 8.0, trailing: .zero))
                VStack(alignment: .leading) {
                    Text(R.string.localizable.settingsByeDPIProxySection)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(Color(R.color.grSecondary))
                    SettingsEditableInfoView(title: R.string.localizable.settingsByeDPIProxyIpAddr(), value: $ipAddr, leadingIcon: Image(R.image.icWorld), validator: { input in
                        if (input.isEmpty) {
                            return false
                        }
                        let splitted = input.split(separator: ".")
                        if (splitted.count != 4) {
                            return false
                        }
                        for ipByte in splitted {
                            if (!ipByte.isEmpty) {
                                continue
                            }
                            if let _ = UInt8(ipByte) {
                                continue
                            }
                            return false
                        }
                        return true
                    }, onNewValue: { newVal in
                        if (properties.byeDPILaunchConfig.listenIP == newVal) {
                            return
                        }
                        ipAddr = newVal
                        properties.byeDPILaunchConfig = properties.byeDPILaunchConfig.copyWith(listenIP: newVal)
                        properties.save()
                    }, keyboardType: .numbersAndPunctuation, autocapitalizationType: .none)
                    SettingsEditableInfoView(title: R.string.localizable.settingsByeDPIProxyPort(), value: $port, leadingIcon: Image(R.image.icWorld), validator: { input in
                        if (input.isEmpty) {
                            return false
                        }
                        guard let _ = UInt16(input) else {
                            return false
                        }
                        return true
                    }, onNewValue: { newVal in
                        guard let parsedNum = UInt16(newVal) else {
                            return
                        }
                        if (properties.byeDPILaunchConfig.listenPort == parsedNum) {
                            return
                        }
                        port = newVal
                        properties.byeDPILaunchConfig = properties.byeDPILaunchConfig.copyWith(listenPort: parsedNum)
                        properties.save()
                    }, keyboardType: .numberPad, autocapitalizationType: .none)
                    SettingsEditableInfoView(title: R.string.localizable.settingsByeDPIProxyBufSize(), value: $bufSize, leadingIcon: Image(R.image.icDb), validator: { input in
                        if (input.isEmpty) {
                            return false
                        }
                        guard let parsedInput = Int(input), parsedInput > 0 else {
                            return false
                        }
                        return true
                    }, onNewValue: { newVal in
                        guard let parsedNum = UInt32(newVal), parsedNum > 0 else {
                            return
                        }
                        if (properties.byeDPILaunchConfig.bufSize == parsedNum) {
                            return
                        }
                        bufSize = newVal
                        properties.byeDPILaunchConfig = properties.byeDPILaunchConfig.copyWith(bufSize: parsedNum)
                        properties.save()
                    }, keyboardType: .numberPad, autocapitalizationType: .none)
                }
                .padding(EdgeInsets(top: .zero, leading: .zero, bottom: 8.0, trailing: .zero))
                VStack(alignment: .leading) {
                    Text(R.string.localizable.settingsAboutSecton)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(Color(R.color.grSecondary))
                    Link(destination: URL(string: Constants.sourceCodeLink)!) {
                        SettingsStaticInfoView(title: R.string.localizable.settingsAboutSourceCode(), text: "Github", leadingIcon: Image(R.image.icGithub))
                    }
                    SettingsStaticInfoView(title: R.string.localizable.settingsAboutAppVersionCode(), text: Constants.PSEUDO_BUNDLE_VERSION, leadingIcon: Image(R.image.icInfo))
                    SettingsStaticInfoView(title: R.string.localizable.settingsAboutByeDPIVersion(), text: ByeDPI.versionCode, leadingIcon: Image(R.image.icInfo))
                }
                Rectangle()
                    .frame(width: 1.0, height: 12.0)
                    .opacity(0.0)
            }
            .padding(.horizontal, 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            dnsOverAddr = properties.dnsOverAddr
            resolvedDnsServers = properties.resolvedDnsServers.joined(separator: " ")
            ipAddr = properties.byeDPILaunchConfig.listenIP
            port = String(properties.byeDPILaunchConfig.listenPort)
            bufSize = String(properties.byeDPILaunchConfig.bufSize)
            //Launch speed up tip - Load data from storage for domains/strategies/tests??
        }
        .onDisappear {
            let tempDirUrl = FileManager.default.temporaryDirectory
            let exportFileUrl = tempDirUrl.appendingPathComponent("bbdconfig.json", isDirectory: false)
            try? FileManager.default.removeItem(at: exportFileUrl)
        }
#if !os(tvOS)
        .navigationTitle(R.string.localizable.generalSettings())
#if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
#endif
    }
}

#if DEBUG
#Preview {
    NavigationView {
        SettingsScreen()
    }
    .environmentObject(previewProperties)
    .environmentObject(previewDomainsManager)
    .environmentObject(previewStrategiesManager)
    .environmentObject(previewTestManager)
}
#endif
