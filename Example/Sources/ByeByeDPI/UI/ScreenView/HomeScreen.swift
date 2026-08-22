//
//  ContentView.swift
//  ByeDPI-iOS
//
//  Created by developer on 24.02.2026.
//

import SwiftUI
#if canImport(ByeDPIKit)
import ByeDPIKit
#elseif canImport(ByeDPIKitLib)
import ByeDPIKitLib
#endif
import SwByeDPI

struct HomeScreen: View {
    
    private enum AlertType: UInt8, Identifiable {
        case vpnEnabledHint
        case vpnStartError
        
        var id: UInt8 {
            get {
                return self.rawValue
            }
        }
    }
    
    @EnvironmentObject fileprivate var properties: AppProperties
    @EnvironmentObject fileprivate var lnwPermissionManager: LNWPermissionManager
    @EnvironmentObject fileprivate var neManager: NEObservableManager
    
    @State var vpnStartFailErrorText = ""
    @State private var showAlertType: AlertType? = nil
    {
        didSet {
            if (showAlertType == nil) {
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now().advanced(by: DispatchTimeInterval.seconds(3))) {
                if (showAlertType == nil) {
                    return
                }
                showAlertType = nil
            }
        }
    }
    
    fileprivate var byeDPIProxyAddr: String {
        get {
            return properties.byeDPILaunchConfig.listenIP + ":" + String(properties.byeDPILaunchConfig.listenPort)
        }
    }
    
    var body: some View {
        VStack(alignment: .center, spacing: 8.0) {
            Spacer(minLength: 16)
            Text(R.string.localizable.palkaTitle())
                .font(.largeTitle)
                .fontWeight(.bold)
            Text(R.string.localizable.palkaSubtitle())
                .foregroundColor(Color(R.color.grSecondary))
                .font(.subheadline)
            Button {
                toggleVpn()
            } label: {
                Image(R.image.icPower)
                    .resizable()
                    .frame(width: 48, height: 48)
                    .foregroundColor(.white)
            }
            .frame(width: 120, height: 120, alignment: .center)
            .background(Color(neManager.vpnRunning
                              ? R.color.grPositive
                              : R.color.grAccent))
            .cornerRadius(120)
            Text(neManager.vpnRunning ? R.string.localizable.homeVpnStateOn : R.string.localizable.homeVpnStateOff)
                .foregroundColor(Color(R.color.grSecondary))
                .font(.caption)
                .fontWeight(.semibold)
            Text(byeDPIProxyAddr)
                .foregroundColor(Color(R.color.grSecondary))
                .font(.caption)
            Text(R.string.localizable.palkaPreset(PalkaPreset.name))
                .foregroundColor(Color(R.color.grSecondary))
                .font(.caption)
                .fontWeight(.semibold)
            Spacer(minLength: 16)
            if (neManager.vpnRunning) {
                Button {
                    if (showAlertType == .vpnEnabledHint) {
                        return
                    }
                    showAlertType = .vpnEnabledHint
                } label: {
                    Text(R.string.localizable.generalSettings)
                }
                .padding(EdgeInsets(top: .zero, leading: 16.0, bottom: 12.0, trailing: 16.0))
            } else {
                NavigationLink {
                    SettingsScreen()
                } label: {
                    Text(R.string.localizable.generalSettings)
                }
                .padding(EdgeInsets(top: .zero, leading: 16.0, bottom: 12.0, trailing: 16.0))
            }
        }
        .alert(isPresented: Binding(get: {
            return showAlertType != nil
        }, set: { newVal in
            if (newVal) {
                return
            }
            showAlertType = nil
        }), content: {
            if (!vpnStartFailErrorText.isEmpty) {
                return Alert(title: Text(R.string.localizable.homeStartByeDPIErrTitle), message: Text(vpnStartFailErrorText))
            }
            return Alert(title: Text(R.string.localizable.homeSettingsAccessHint))
        })
    }
    
    fileprivate func toggleVpn() {
#if DEBUG
        if (ProcessInfo.processInfo.previewMode) {
            if (neManager.vpnRunning) {
                vpnStartFailErrorText = "Preview text error"
                showAlertType = .vpnStartError
                neManager.stopConnection()
                return
            }
            vpnStartFailErrorText = ""
            neManager.startConnection { success, error in
                
            }
            return
        }
#endif
        vpnStartFailErrorText = ""
        if (neManager.vpnRunning) {
            neManager.stopConnection()
            return
        }
        if (properties.byeDPILaunchConfig.listenIP == "0.0.0.0") {
            lnwPermissionManager.checkAndRequestPermission { status in
                print(status)
            }
        }
        neManager.startConnection { success, error in
            if let safeErr = error {
                if let byedpiErr = safeErr as? BDError {
                    self.vpnStartFailErrorText = byedpiErr.errorDescription
                } else {
                    self.vpnStartFailErrorText = safeErr.localizedDescription + " (" + String(describing: safeErr)
                }
                self.showAlertType = .vpnStartError
                return
            }
            if (!success) {
                self.vpnStartFailErrorText = R.string.localizable.homeStartByeDPIErrUnknownMsg()
                self.showAlertType = .vpnStartError
                return
            }
        }
    }
}

#if DEBUG
#Preview {
    NavigationView {
        HomeScreen()
    }
    .environmentObject(previewProperties)
    .environmentObject(previewLnwPermissionManager)
    .environmentObject(previewDomainsManager)
    .environmentObject(previewStrategiesManager)
    .environmentObject(previewByeDPIManager)
    .environmentObject(previewNeManager)
    .environmentObject(previewTestManager)
}
#endif
