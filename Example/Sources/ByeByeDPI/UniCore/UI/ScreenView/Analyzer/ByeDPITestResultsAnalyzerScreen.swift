//
//  TestResultsAnalyzerScreen.swift
//  ByeByeDPI
//
//  Created by developer on 17.03.2026.
//

import SwiftUI
import SwByeDPI
#if canImport(UIKit)
import UIKit
#endif

struct ByeDPITestResultsAnalyzerScreen: View {
    
    @EnvironmentObject var properties: AppProperties
    @EnvironmentObject var domainsManager: DomainsManager
    @EnvironmentObject var testManager: TestManager
    
    @State fileprivate var _synthesizedStrategyCmd: [String] = []
    @State fileprivate var _synthesizedStrategyCmdLine = ""
    
    @State fileprivate var _refreshCmdDisabled = false
    
    @State fileprivate var _bypassDnsPortCmd: [String] = []
    @State fileprivate var _useDnsBypass = true
    
    @State fileprivate var _blackListCmd: [String] = []
    @State fileprivate var _useBlackList = true
    
    @State fileprivate var _whiteListCmd: [String] = []
    @State fileprivate var _whiteListWithoutUniversalCmd: [String] = []
    @State fileprivate var _useWhiteList = true
    
    @State fileprivate var _universalCmd: [String] = []
    @State fileprivate var _useUniversal = true
    
    @State fileprivate var _showPickerSheet = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: .zero) {
                        Text(R.string.localizable.byeDPITestAnalyzerFormatHint() + ":")
                            .font(.body)
                            .foregroundColor(Color(R.color.grPrimary))
                            .padding(EdgeInsets(top: 8, leading: .zero, bottom: 8, trailing: .zero))
                        VStack(alignment: .leading, spacing: 8.0) {
                            Text("• " + R.string.localizable.byeDPITestAnalyzerFormatInfo1())
                                .font(.footnote)
                                .foregroundColor(Color(R.color.grPrimary))
                            Text("• " + R.string.localizable.byeDPITestAnalyzerFormatInfo2())
                                .font(.footnote)
                                .foregroundColor(Color(R.color.grPrimary))
                            Text("• " + R.string.localizable.byeDPITestAnalyzerFormatInfo3())
                                .font(.footnote)
                                .foregroundColor(Color(R.color.grPrimary))
                            Text("• " + R.string.localizable.byeDPITestAnalyzerFormatInfo4())
                                .font(.footnote)
                                .foregroundColor(Color(R.color.grPrimary))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 8))
                        .background(Color(R.color.bgSecondary))
                        .cornerRadius(12.0)
                        Text(R.string.localizable.byeDPITestAnalyzerHint)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(Color(R.color.grPrimary))
                            .padding(EdgeInsets(top: 8, leading: .zero, bottom: 16, trailing: .zero))
                        if (testManager.lastCheckResults.isEmpty) {
                            Text(R.string.localizable.byeDPITestAnalyzerNoTestResults)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .font(.headline.weight(.semibold))
                                .foregroundColor(Color(R.color.grError))
                                .multilineTextAlignment(.center)
                        } else {
                            Toggle(isOn: Binding(get: {
                                return _useDnsBypass
                            }, set: { newVal in
                                _useDnsBypass = newVal
                                refreshSynthesizedCmd()
                            })) {
                                Text(R.string.localizable.byeDPITestAnalyzerUseDnsBypassSwitch)
                                    .foregroundColor(Color(R.color.grPrimary))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 8))
                            .background(Color(R.color.bgSecondary))
                            .cornerRadius(12.0)
                            Rectangle()
                                .frame(width: 1, height: 8)
                                .foregroundColor(Color.clear)
                            VStack(alignment: .leading, spacing: .zero) {
                                Toggle(isOn: Binding(get: {
                                    return _useBlackList
                                }, set: { newVal in
                                    _useBlackList = newVal
                                    refreshSynthesizedCmd()
                                })) {
                                    Text(R.string.localizable.byeDPITestAnalyzerUseDomainBypassSwitch)
                                        .foregroundColor(Color(R.color.grPrimary))
                                }
                                Button {
                                    if (_showPickerSheet) {
                                        return
                                    }
                                    _showPickerSheet = true
                                } label: {
                                    Text(R.string.localizable.byeDPITestAnalyzerBypassPick)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                Text(R.string.localizable.settingsItemsCountPrefix() + " - " + String(properties.byeDPIDomainListsIDsBypass.count))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(Color(R.color.grPrimary))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 8))
                            .background(Color(R.color.bgSecondary))
                            .cornerRadius(12.0)
                            Rectangle()
                                .frame(width: 1, height: 8)
                                .foregroundColor(Color.clear)
                            Toggle(isOn: Binding(get: {
                                return _useWhiteList
                            }, set: { newVal in
                                _useWhiteList = newVal
                                refreshSynthesizedCmd()
                            })) {
                                Text(R.string.localizable.byeDPITestAnalyzerUseDomainSpecificSwitch)
                                    .foregroundColor(Color(R.color.grPrimary))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 8))
                            .background(Color(R.color.bgSecondary))
                            .cornerRadius(12.0)
                            Rectangle()
                                .frame(width: 1, height: 8)
                                .foregroundColor(Color.clear)
                            Toggle(isOn: Binding(get: {
                                return _useUniversal
                            }, set: { newVal in
                                _useUniversal = newVal
                                refreshSynthesizedCmd()
                            })) {
                                Text(R.string.localizable.byeDPITestAnalyzerUseUniversalSwitch)
                                    .foregroundColor(Color(R.color.grPrimary))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 8))
                            .background(Color(R.color.bgSecondary))
                            .cornerRadius(12.0)
                            Rectangle()
                                .frame(width: 1, height: 16)
                                .foregroundColor(Color.clear)
                            Text(R.string.localizable.byeDPITestAnalyzerRetrievedStrategy)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(Color(R.color.grSecondary))
#if os(tvOS)
                            TextField(R.string.localizable.byeDPITestAnalyzerRetrievedStrategy(), text: $_synthesizedStrategyCmdLine, axis: .vertical)
                                .padding(EdgeInsets(top: 4, leading: 0, bottom: 0, trailing: 0))
                                .lineLimit(4, reservesSpace: true)
                                .disabled(true)
#else
                            TextEditor(text: $_synthesizedStrategyCmdLine)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(R.color.bgSecondary), lineWidth: 1))
                                .padding(EdgeInsets(top: 4, leading: 0, bottom: 0, trailing: 0))
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .disabled(true)
#endif
                            
                            Rectangle()
                                .frame(width: 1, height: 12)
                                .foregroundColor(Color.clear)
                            HStack(alignment: .center, spacing: 8.0) {
                                Button {
                                    if (_synthesizedStrategyCmd.isEmpty) {
                                        return
                                    }
                                    properties.applyCustomStrategy(
                                        name: palkaLocalized("palkaAnalyzedStrategy"),
                                        commandArgs: _synthesizedStrategyCmd
                                    )
                                } label: {
                                    Text(R.string.localizable.byeDPITestAnalyzerApply)
                                        .foregroundColor(Color(R.color.grPrimary))
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity, minHeight: Constants.buttonMinHeight, alignment: .center)
                                .background(Color(R.color.bgTertiary))
                                .cornerRadius(12.0)
#if canImport(UIKit) && !os(tvOS)
                                Button {
                                    if (_synthesizedStrategyCmdLine.isEmpty) {
                                        return
                                    }
                                    UIPasteboard.general.string = _synthesizedStrategyCmdLine
                                } label: {
                                    Text(R.string.localizable.byeDPITestAnalyzerCopy)
                                        .foregroundColor(Color(R.color.grPrimary))
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity, minHeight: Constants.buttonMinHeight, alignment: .center)
                                .background(Color(R.color.bgTertiary))
                                .cornerRadius(12.0)
#endif
                            }
                            Rectangle()
                                .frame(width: 1, height:8)
                                .foregroundColor(Color.clear)
                        }
                        Rectangle()
                            .frame(width: 1, height: Constants.buttonMinHeight + 12)
                            .foregroundColor(Color.clear)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                }
                .frame(maxHeight: .infinity)
                Button {
                    if (testManager.lastCheckResults.isEmpty) {
                        return
                    }
                    var dpiBypassSLDs = Set<String>()
                    let domainLists = domainsManager.controller.domainLists
                    for id in properties.byeDPIDomainListsIDsBypass {
                        guard let safeDomainList = domainLists[id] else {
                            continue
                        }
                        for domain in safeDomainList.domains {
                            guard let safeSld = SBDDomainUtil.retrieveSLD(domain), !dpiBypassSLDs.contains(safeSld) else {
                                continue
                            }
                            dpiBypassSLDs.insert(safeSld)
                        }
                    }
                    let profitStrategies = SBDTestResultAnalyticsUtil.retrieveProfitStrategiesWithSuccessSLDs(testResults: testManager.checkResults)
                    _refreshCmdDisabled = true
                    _bypassDnsPortCmd = SBDTestResultAnalyticsUtil.retrieveDPIBypassDnsCmd()
                    _whiteListCmd = SBDTestResultAnalyticsUtil.retrieveProfiStrategiesForDomainsCmd(profitStrategies: profitStrategies, withUniversal: true)
                    _whiteListWithoutUniversalCmd = SBDTestResultAnalyticsUtil.retrieveProfiStrategiesForDomainsCmd(profitStrategies: profitStrategies, withUniversal: false)
                    var universalCmd: [String] = []
                    for entry in profitStrategies {
                        if (!entry.value.universal) {
                            continue
                        }
                        universalCmd = entry.key.cmdArgs
                        break
                    }
                    _universalCmd = universalCmd
                    _blackListCmd = SBDTestResultAnalyticsUtil.retrieveDPIBypassDomainsCmd(dpiBypassSLDs)
                    _refreshCmdDisabled = false
                    refreshSynthesizedCmd()
                } label: {
                    Text(R.string.localizable.byeDPITestAnalyzerRetrieve)
                        .foregroundColor(Color(R.color.grPrimary))
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity, minHeight: Constants.buttonMinHeight, alignment: .center)
                .background(Color(R.color.bgTertiary))
                .cornerRadius(12.0)
                .padding(EdgeInsets(top: .zero, leading: 20, bottom: geometry.safeAreaInsets.bottom > 0 ? 0 : 12, trailing: 20))
            }
        }
        .sheet(isPresented: $_showPickerSheet, onDismiss: {
            _showPickerSheet = false
        }, content: {
            ListPickerScreen(lists: domainsManager.controller.domainLists.values.sorted(by: { a, b in
                a.name.compare(b.name) == .orderedDescending
            }), initCheckedListIDs: properties.byeDPIDomainListsIDsBypass, presented: $_showPickerSheet) { lists, picked in
                properties.byeDPIDomainListsIDsBypass = picked
                properties.save()

                var dpiBypassSLDs = Set<String>()
                let domainLists = domainsManager.controller.domainLists
                for id in properties.byeDPIDomainListsIDsBypass {
                    guard let safeDomainList = domainLists[id] else {
                        continue
                    }
                    for domain in safeDomainList.domains {
                        guard let safeSld = SBDDomainUtil.retrieveSLD(domain), !dpiBypassSLDs.contains(safeSld) else {
                            continue
                        }
                        dpiBypassSLDs.insert(safeSld)
                    }
                }
                _blackListCmd = SBDTestResultAnalyticsUtil.retrieveDPIBypassDomainsCmd(dpiBypassSLDs)
            }
        })
#if !os(tvOS)
        .navigationTitle(R.string.localizable.byeDPITestAnalyzerNavTitle())
#if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
#endif
    }
    
    fileprivate func refreshSynthesizedCmd() {
        if (_refreshCmdDisabled) {
            return
        }
        let dnsBypass = _useDnsBypass ? _bypassDnsPortCmd : nil
        let blackList = _useBlackList ? _blackListCmd : nil
        var whitelist: [String]? = nil
        if (_useWhiteList) {
            if (_useUniversal) {
                // Use whitelist strategy part without universal one
                whitelist = _whiteListWithoutUniversalCmd
            } else {
                whitelist = _whiteListCmd
            }
        }
        let universal = _useUniversal ? _universalCmd : nil
        var cmd = SBDTestResultAnalyticsUtil.retrieveCompositeByeDPIConfigCmdArgs(byedpiBypassDns: false, byedpiBypassSLDCmd: blackList, profitStrategiesWithDomainsCmd: whitelist, universalStrategyCmd: universal)
        if let safeDnsBypass = dnsBypass {
            cmd.insert(contentsOf: safeDnsBypass, at: 0)
        }
        _synthesizedStrategyCmd = cmd
        _synthesizedStrategyCmdLine = _synthesizedStrategyCmd.joined(separator: " ")
    }
}

#if DEBUG
#Preview {
    NavigationView {
        ByeDPITestResultsAnalyzerScreen()
    }
    .environmentObject(previewProperties)
    .environmentObject(previewDomainsManager)
    .environmentObject(previewTestManager)
}
#endif
