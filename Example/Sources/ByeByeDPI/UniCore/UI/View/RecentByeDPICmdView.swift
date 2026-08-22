//
//  RecentByeDPICmdView.swift
//  ByeByeDPI
//
//  Created by developer on 13.03.2026.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct RecentByeDPICmdView: View {
    
    @EnvironmentObject var properties: AppProperties
    
    fileprivate let _line: String
    
    fileprivate var _cmdArgs: [String] {
        get {
            let splitted = _line.split(separator: " ")
            return [String].init(splitted.map({ subStr in
                return String(subStr)
            }))
        }
    }
    
    fileprivate var _applied: Bool {
        get {
            _cmdArgs == properties.byeDPILaunchConfig.cmdArgs
        }
    }
    
    @State fileprivate var showDeleteActionSheet = false
    
    init(line: String) {
        _line = line
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4.0) {
            HStack(alignment: .top, spacing: 4.0) {
                Text("•")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(R.color.grPrimary))
                Text(_line)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(R.color.grPrimary))
            }
            HStack(alignment: .center, spacing: 8.0) {
                if (_applied) {
                    Text(R.string.localizable.byeDPICmdEditorHistorySelectedItem)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(Color(R.color.grAccent))
                }
                Spacer(minLength: 8.0)
                Button {
                    if (_applied) {
                        return
                    }
                    properties.applyCustomStrategy(
                        name: palkaLocalized("palkaCustomStrategy"),
                        commandArgs: _cmdArgs
                    )
                } label: {
                    Image(R.image.icCheck)
                        .resizable()
                        .frame(width: 20, height: 18)
                        .foregroundColor(Color(R.color.grPositive))
                }
                .frame(width: 26, height: 28, alignment: .center)
                .cornerRadius(32)
#if canImport(UIKit) && !os(tvOS)
                Button {
                    UIPasteboard.general.string = _line
                } label: {
                    Image(R.image.icCopy)
                        .resizable()
                        .frame(width: 20, height: 22)
                        .foregroundColor(Color(R.color.grAccent))
                }
                .frame(width: 26, height: 28, alignment: .center)
                .cornerRadius(32)
#endif
#if os(macOS)
                Button {
                    for i in 0..<properties.byeDPICmdEditorHistory.count {
                        if (properties.byeDPICmdEditorHistory[i] != _line) {
                            continue
                        }
                        _ = properties.removeRecentCmd(at: i)
                        properties.save()
                        break
                    }
                } label: {
                    Image(R.image.icTrash)
                        .resizable()
                        .frame(width: 20, height: 22)
                        .foregroundColor(Color(R.color.grError))
                }
                .frame(width: 26, height: 28, alignment: .center)
                .cornerRadius(32)
#else
                Button {
                    if (showDeleteActionSheet) {
                        return
                    }
                    showDeleteActionSheet = true
                } label: {
                    Image(R.image.icTrash)
                        .resizable()
                        .frame(width: 20, height: 22)
                        .foregroundColor(Color(R.color.grError))
                }
                .frame(width: 26, height: 28, alignment: .center)
                .cornerRadius(32)
                .actionSheet(isPresented: $showDeleteActionSheet, content: {
                    ActionSheet(title: Text(R.string.localizable.generalDeleteSheetTitle), buttons: [
                        .destructive(Text(R.string.localizable.generalDelete), action: {
                            for i in 0..<properties.byeDPICmdEditorHistory.count {
                                if (properties.byeDPICmdEditorHistory[i] != _line) {
                                    continue
                                }
                                _ = properties.removeRecentCmd(at: i)
                                properties.save()
                                break
                            }
                            showDeleteActionSheet = false
                        }),
                        .cancel(Text(R.string.localizable.generalCancel), action: {
                            showDeleteActionSheet = false
                        })
                    ])
                })
#endif
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 8))
        .background(Color(R.color.bgSecondary))
        .cornerRadius(12.0)
    }
}

#if DEBUG
#Preview {
    VStack(alignment: .center, spacing: 8.0) {
        RecentByeDPICmdView(line: "some cmd args arr #1")
        RecentByeDPICmdView(line: "some cmd args arr #2")
        RecentByeDPICmdView(line: "some cmd args arr #3")
    }
    .environmentObject(previewProperties)
}
#endif
