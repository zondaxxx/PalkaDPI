//
//  ByeDPIStrategyTesterScreen.swift
//  ByeByeDPI
//
//  Created by developer on 05.03.2026.
//

import SwiftUI
import SwByeDPI
#if canImport(UIKit)
import UIKit
#endif

struct ByeDPIStrategyTesterScreen: View {
    
    @EnvironmentObject var properties: AppProperties
    @EnvironmentObject var domainsManager: DomainsManager
    @EnvironmentObject var strategiesManager: StrategiesManager
    @EnvironmentObject var testManager: TestManager
    
    @State fileprivate var _totalDomainRequestsCount: Int
    @State fileprivate var _testingProgressInfo: String
    
    init() {
        __totalDomainRequestsCount = State(initialValue: 100000)
        __testingProgressInfo = State(initialValue: R.string.localizable.byeDPITestStateNotStarted())
    }
    
    var body: some View {
        VStack(alignment: .center, spacing: 8.0) {
            Button {
                if (testManager.testingInProgress) {
                    testManager.cancelTest()
                    _testingProgressInfo = palkaLocalized("palkaTesterStopping")
                    return
                }
                _totalDomainRequestsCount = properties.byeDPITestConfig.retrieveDomains(domainLists: domainsManager.lists).count * Int(properties.byeDPITestConfig.domainRequestsCount)
#if DEBUG
                if (ProcessInfo.processInfo.previewMode) {
                    //Not start the real ByeDPI
                    return
                }
#endif
                testManager.test(config: properties.byeDPITestConfig, domainLists: domainsManager.lists, strategyLists: strategiesManager.lists) { result in
                    self._testingProgressInfo = R.string.localizable.byeDPITestStateNotStarted()
                }
            } label: {
                if (testManager.testingInProgress) {
                    Text(R.string.localizable.byeDPITestStop)
                        .foregroundColor(Color(R.color.grPrimary))
                        .fontWeight(.semibold)
                } else {
                    Text(R.string.localizable.byeDPITestStart)
                        .foregroundColor(Color(R.color.grPrimary))
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity, minHeight: Constants.buttonMinHeight, alignment: .center)
            .background(Color(R.color.bgTertiary))
            .cornerRadius(12.0)
            .padding(.horizontal, 32)
            Text(_testingProgressInfo)
            .foregroundColor(Color(R.color.grSecondary))
            .fontWeight(.semibold)
            .padding(.horizontal, 16)
            Text(palkaLocalized("palkaTesterTransportHint"))
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(Color(R.color.grSecondary))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            if let errorText = testManager.lastErrorText {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(errorText)
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .padding(.horizontal, 16)
            }
            ScrollView(.vertical) {
                LazyVStack(alignment: .leading, spacing: 8.0) {
                    ForEach(testManager.lastCheckResults, id: \.strategy.id) { strategyTestResult in
                        StrategyTestResultView(strategyCmdArgs: strategyTestResult.strategy.cmdArgs, totalDomainRequestsCount: _totalDomainRequestsCount, domainsSuccessTestResults: strategyTestResult.sortedDomainsTestsResult.map({ domainTestResult in
                            return (domain: domainTestResult.domain, successRequestsCount: domainTestResult.successRequestsCount, failRequestsCount: domainTestResult.failedRequestsCount, successTest: domainTestResult.successTest)
                        }))
                        .id(strategyTestResult.strategy.id)
                    }
                    .padding(.horizontal, 12)
                }
            }
        }
        .onAppear {
#if canImport(UIKit)
            UIApplication.shared.isIdleTimerDisabled = true
#endif
            _totalDomainRequestsCount = properties.byeDPITestConfig.retrieveDomains(domainLists: domainsManager.lists).count * Int(properties.byeDPITestConfig.domainRequestsCount)
        }
        .onDisappear {
#if canImport(UIKit)
            UIApplication.shared.isIdleTimerDisabled = false
#endif
            testManager.cancelTest()
        }
        .onReceive(NotificationCenter.default.publisher(for: .SBDNoTestingStrategy), perform: { notification in
            _testingProgressInfo = R.string.localizable.byeDPITestStateNotStarted()
        })
        .onReceive(NotificationCenter.default.publisher(for: .SBDTestingProgressUpdate), perform: { notification in
            let parseRes = notification.tryParseTestingProgressFromNotification()
            guard let progress = parseRes.1 else {
                return
            }
            _testingProgressInfo = R.string.localizable.byeDPITestStateInProgress() + " " + String(progress.tested) + "/" + String(progress.total)
        })
#if !os(tvOS)
        .navigationTitle(R.string.localizable.byeDPITestNavTitle())
#if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
#endif
#if !os(macOS)
        .toolbar {
            #if !os(tvOS)
            let imgHeight = 24.0
            #else
            let imgHeight = 32.0
            #endif
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    ByeDPIStrategyTesterSettingsScreen(testConfig: properties.byeDPITestConfig, onUpdate: { testConfig in
                        properties.byeDPITestConfig = testConfig
                        properties.save()
                    }, testSingleStrategyMode: false)
                } label: {
                    Image(R.image.icSettings)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: imgHeight)
                }
            }
        }
#endif
    }
}

#if DEBUG
#Preview {
    NavigationView {
        ByeDPIStrategyTesterScreen()
    }
    .environmentObject(previewProperties)
    .environmentObject(previewDomainsManager)
    .environmentObject(previewStrategiesManager)
    .environmentObject(previewTestManager)
}
#endif
