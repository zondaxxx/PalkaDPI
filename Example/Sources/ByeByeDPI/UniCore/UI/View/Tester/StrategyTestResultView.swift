//
//  StrategyTestResultView.swift
//  ByeByeDPI
//
//  Created by developer on 13.03.2026.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct StrategyTestResultView: View {
    
    @EnvironmentObject var properties: AppProperties
    
    fileprivate let _strategyCmdArgs: [String]
    fileprivate let _strategyCmdLine: String
    fileprivate let _successDomainRequestsCount: Int
    fileprivate let _totalDomainRequestsCount: Int
    
    fileprivate let _domainsSuccessTestResults: [DomainTestResultTreeEntry]
    
    fileprivate var _successDomainRequestsPercent: Double {
        let progress = Double(_successDomainRequestsCount) / Double(_totalDomainRequestsCount)
        if (progress > 1.0) {
            return 1.0
        }
        return progress
    }
    
    fileprivate var _formattedStrategyTestProgressInfo: String {
        get {
            return String(_successDomainRequestsCount) + "/" + String(_totalDomainRequestsCount)
        }
    }
    
    @State fileprivate var _expanded: Bool
    @State fileprivate var _strategyActionSheetShow: Bool
    
    init(strategyCmdArgs: [String], totalDomainRequestsCount: Int, domainsSuccessTestResults: [(domain: String, successRequestsCount: UInt8, failRequestsCount: UInt8, successTest: Bool)]) {
        self._strategyCmdArgs = strategyCmdArgs
        self._strategyCmdLine = strategyCmdArgs.joined(separator: " ")
        var calculatedTotalDomainRequestsCount = 0
        var successRequestsCount = 0
        var treeEntries: [DomainTestResultTreeEntry] = []
        for entry in domainsSuccessTestResults {
            successRequestsCount += Int(entry.successRequestsCount)
            let totalDomainTestRequests = Int(entry.successRequestsCount) + Int(entry.failRequestsCount)
            calculatedTotalDomainRequestsCount += totalDomainTestRequests
            treeEntries.append(DomainTestResultTreeEntry(domain: entry.domain, successRequestsCount: Int(entry.successRequestsCount), totalRequestsCount: totalDomainTestRequests, successTest: entry.successTest))
        }
        self._successDomainRequestsCount = successRequestsCount
        if (calculatedTotalDomainRequestsCount > totalDomainRequestsCount) {
            //Outside settings edited for previously cached test result -> use calculated value
            self._totalDomainRequestsCount = calculatedTotalDomainRequestsCount
        } else {
            self._totalDomainRequestsCount = totalDomainRequestsCount
        }
        self._domainsSuccessTestResults = treeEntries
        __expanded = State(initialValue: false)
        __strategyActionSheetShow = State(initialValue: false)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8.0) {
            Button {
                if (_strategyActionSheetShow) {
                    return
                }
                _strategyActionSheetShow = true
            } label: {
                Text(_strategyCmdLine)
                    .foregroundColor(Color(R.color.grPrimary))
                    .underline(true, color: Color(R.color.grAccent))
                    .multilineTextAlignment(.leading)
            }
    #if !os(tvOS)
            .actionSheet(isPresented: $_strategyActionSheetShow) {
                ActionSheet(title: Text(_strategyCmdLine), buttons: [
                    .default(Text(R.string.localizable.generalApply), action: {
                        properties.applyCustomStrategy(
                            name: palkaLocalized("palkaTestedStrategy"),
                            commandArgs: _strategyCmdArgs
                        )
                    }),
                    .default(Text(R.string.localizable.generalCopy), action: {
                        UIPasteboard.general.string = _strategyCmdLine
                    }),
                    .cancel(Text(R.string.localizable.generalCancel), action: {
                        _strategyActionSheetShow = false
                    }),
                ])
            }
    #else
            .actionSheet(isPresented: $_strategyActionSheetShow) {
                ActionSheet(title: Text(_strategyCmdLine), buttons: [
                    .default(Text(R.string.localizable.generalApply), action: {
                        properties.applyCustomStrategy(
                            name: palkaLocalized("palkaTestedStrategy"),
                            commandArgs: _strategyCmdArgs
                        )
                    }),
                    .cancel(Text(R.string.localizable.generalCancel), action: {
                        _strategyActionSheetShow = false
                    }),
                ])
            }
    #endif
            HStack(alignment: .center, spacing: 12.0) {
                ProgressView(value: _successDomainRequestsPercent, total: 1.0)
                    .frame(maxWidth: .infinity)
                Text(_formattedStrategyTestProgressInfo)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(R.color.grSecondary))
            }
#if os(tvOS)
            Button {
                _expanded = !_expanded
            } label: {
                if (_expanded) {
                    Text(R.string.localizable.byeDPITestDomainsDetailsHide)
                } else {
                    Text(R.string.localizable.byeDPITestDomainsDetailsShow)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            if (_expanded) {
                VStack(alignment: .leading, spacing: 4.0) {
                    ForEach(_domainsSuccessTestResults) { domainTestResult in
                        VStack(alignment: .leading, spacing: .zero) {
                            DomainTestResultView(domain: domainTestResult.domain, successRequestsCount: UInt8(domainTestResult.successRequestsCount), totalRequestsCount: UInt8(domainTestResult.totalRequestsCount), successTest: domainTestResult.successTest)
                            Divider()
                        }
                        .id(domainTestResult.domain)
                    }
                }
                .transition(.opacity)
            }
#else
            DisclosureGroup(isExpanded: $_expanded, content: {
                ForEach(_domainsSuccessTestResults) { domainTestResult in
                    VStack(alignment: .leading, spacing: .zero) {
                        DomainTestResultView(domain: domainTestResult.domain, successRequestsCount: UInt8(domainTestResult.successRequestsCount), totalRequestsCount: UInt8(domainTestResult.totalRequestsCount), successTest: domainTestResult.successTest)
                        Divider()
                    }
                    .id(domainTestResult.domain)
                }
            }, label: {
                if (_expanded) {
                    Text(R.string.localizable.byeDPITestDomainsDetailsHide)
                } else {
                    Text(R.string.localizable.byeDPITestDomainsDetailsShow)
                }
                
            })
#endif
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 8))
        .background(Color(R.color.bgSecondary))
        .cornerRadius(12.0)
    }
}

fileprivate struct DomainTestResultTreeEntry: Identifiable {
    
    let id = UUID()
    fileprivate let domain: String
    fileprivate let successRequestsCount: Int
    fileprivate let totalRequestsCount: Int
    fileprivate let successTest: Bool
    
}

#if DEBUG
#Preview {
    let totalDomainRequestsCount = 10
    let domainRequestsCount: UInt8 = 2
    
    ScrollView(.vertical) {
        VStack(alignment: .center, spacing: 8.0) {
            StrategyTestResultView(strategyCmdArgs: ["-cmd", "-arg", "-name", "-dat"], totalDomainRequestsCount: totalDomainRequestsCount, domainsSuccessTestResults: [
                (domain: "site.com", successRequestsCount: UInt8(1), failRequestsCount: domainRequestsCount - 1, successTest: true),
                (domain: "site2.com", successRequestsCount: UInt8(0), failRequestsCount: domainRequestsCount, successTest: false),
                (domain: "sub.domain.site.com", successRequestsCount: UInt8(2), failRequestsCount: 0, successTest: true),
                (domain: "site-another.com", successRequestsCount: UInt8(1), failRequestsCount: domainRequestsCount - 1, successTest: true),
                (domain: "site3.com", successRequestsCount: UInt8(0), failRequestsCount: domainRequestsCount, successTest: false),
            ])
            StrategyTestResultView(strategyCmdArgs: ["-cmd2", "-arg2", "-name2", "-dat2"], totalDomainRequestsCount: totalDomainRequestsCount, domainsSuccessTestResults: [
                (domain: "site.com", successRequestsCount: UInt8(1), failRequestsCount: domainRequestsCount - 1, successTest: true),
                (domain: "site2.com", successRequestsCount: UInt8(1), failRequestsCount: domainRequestsCount - 1, successTest: true),
                (domain: "sub.domain.site.com", successRequestsCount: UInt8(2), failRequestsCount: 0, successTest: true),
                (domain: "site-another.com", successRequestsCount: UInt8(1), failRequestsCount: domainRequestsCount - 1, successTest: true),
                (domain: "site3.com", successRequestsCount: UInt8(2), failRequestsCount: 0, successTest: true),
            ])
            StrategyTestResultView(strategyCmdArgs: ["-cmd3", "-arg3", "-name3", "-dat3"], totalDomainRequestsCount: totalDomainRequestsCount, domainsSuccessTestResults: [
                (domain: "site.com", successRequestsCount: UInt8(2), failRequestsCount: 0, successTest: true),
                (domain: "site2.com", successRequestsCount: UInt8(0), failRequestsCount: domainRequestsCount, successTest: false),
                (domain: "sub.domain.site.com", successRequestsCount: UInt8(2), failRequestsCount: 0, successTest: true),
                (domain: "site-another.com", successRequestsCount: UInt8(1), failRequestsCount: domainRequestsCount - 1, successTest: true),
                (domain: "site3.com", successRequestsCount: UInt8(0), failRequestsCount: domainRequestsCount, successTest: false),
            ])
            StrategyTestResultView(strategyCmdArgs: ["-cmd4", "-arg4", "-name4", "-dat4"], totalDomainRequestsCount: totalDomainRequestsCount, domainsSuccessTestResults: [
                (domain: "site.com", successRequestsCount: UInt8(0), failRequestsCount: domainRequestsCount, successTest: false),
                (domain: "site2.com", successRequestsCount: UInt8(0), failRequestsCount: domainRequestsCount, successTest: false),
                (domain: "sub.domain.site.com", successRequestsCount: UInt8(0), failRequestsCount: domainRequestsCount, successTest: false),
                (domain: "site-another.com", successRequestsCount: UInt8(0), failRequestsCount: domainRequestsCount, successTest: false),
                (domain: "site3.com", successRequestsCount: UInt8(0), failRequestsCount: domainRequestsCount, successTest: false),
            ])
        }
    }
    .environmentObject(previewProperties)
}
#endif
