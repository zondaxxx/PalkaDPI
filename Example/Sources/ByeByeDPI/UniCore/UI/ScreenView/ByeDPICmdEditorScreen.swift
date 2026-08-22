//
//  ByeDPICmdEditorScreen.swift
//  ByeByeDPI
//
//  Created by developer on 05.03.2026.
//

import SwiftUI
import SwByeDPI

struct ByeDPICmdEditorScreen: View {
    
    @EnvironmentObject var properties: AppProperties
    
    var body: some View {
        VStack(alignment: .center, spacing: .zero) {
            SettingsEditableInfoView(title: R.string.localizable.settingsByeDPIArgsFieldTitle(), value: Binding(get: {
                let strategy = SBDStrategy(cmdArgs: properties.byeDPILaunchConfig.cmdArgs)
                return strategy.cmdArgsLine
            }, set: { newVal in
                let newStrategy = SBDStrategy(cmdLine: newVal)
                properties.applyCustomStrategy(
                    name: palkaLocalized("palkaCustomStrategy"),
                    commandArgs: newStrategy.cmdArgs
                )
            }), leadingIcon: Image(R.image.icCodeTags))
            Divider()
                .padding(EdgeInsets(top: 12, leading: .zero, bottom: 12, trailing: .zero))
            Text(R.string.localizable.byeDPICmdEditorHistory)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(EdgeInsets(top: .zero, leading: .zero, bottom: 12, trailing: .zero))
            ScrollView(.vertical) {
                LazyVStack(alignment: .leading, spacing: 8.0) {
                    ForEach(properties.byeDPICmdEditorHistory, id: \.self) { cmdLine in
                        RecentByeDPICmdView(line: cmdLine)
                            .id(cmdLine)
                    }
                    Rectangle()
                        .frame(width: 1.0, height: 12.0)
                        .opacity(0.0)
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, 16)
#if !os(tvOS)
        .navigationTitle(R.string.localizable.byeDPICmdEditorTitle())
#if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        
#endif
    }
}

#if DEBUG
#Preview {
    NavigationView {
        ByeDPICmdEditorScreen()
    }
    .environmentObject(previewProperties)
}
#endif
