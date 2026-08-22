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
    
    @State private var vpnStartFailErrorText = ""
    @State private var showAlertType: AlertType? = nil
    @State private var connectionActionInFlight = false
    
    fileprivate var byeDPIProxyAddr: String {
        get {
            return properties.byeDPILaunchConfig.listenIP + ":" + String(properties.byeDPILaunchConfig.listenPort)
        }
    }
    
    var body: some View {
        ZStack {
            PalkaBackground()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: PalkaDesign.sectionSpacing) {
                    header
                        .palkaEntrance()
                    connectionCard
                        .palkaEntrance(delay: 0.05)
                    presetCard
                        .palkaEntrance(delay: 0.10)
                    settingsControl
                        .palkaEntrance(delay: 0.15)
                }
                .padding(.horizontal, PalkaDesign.screenPadding)
                .padding(.top, 18)
                .padding(.bottom, 28)
            }
        }
        .foregroundColor(PalkaDesign.textPrimary)
        .navigationBarHidden(true)
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

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(R.string.localizable.palkaTitle())
                    .font(.system(size: 34, weight: .heavy))
                    .tracking(-1.25)

                Text(R.string.localizable.palkaSubtitle())
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(PalkaDesign.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            settingsIconControl
        }
    }

    @ViewBuilder
    private var settingsIconControl: some View {
        if neManager.vpnRunning {
            Button {
                showAlertType = .vpnEnabledHint
            } label: {
                settingsIconLabel
            }
            .buttonStyle(PalkaPressButtonStyle())
            .accessibilityLabel(R.string.localizable.generalSettings())
        } else {
            NavigationLink(destination: SettingsScreen()) {
                settingsIconLabel
            }
            .buttonStyle(PalkaPressButtonStyle())
            .accessibilityLabel(R.string.localizable.generalSettings())
        }
    }

    private var settingsIconLabel: some View {
        Image(systemName: neManager.vpnRunning ? "lock.fill" : "slider.horizontal.3")
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(PalkaDesign.textSecondary)
            .frame(width: 46, height: 46)
            .background(Color.white.opacity(0.06))
            .clipShape(Circle())
            .overlay(Circle().stroke(PalkaDesign.border, lineWidth: 1))
    }

    private var connectionCard: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 8) {
                PalkaStatusDot(isActive: neManager.vpnRunning)

                Text(neManager.vpnRunning
                     ? palkaLocalized("palkaStatusActive")
                     : palkaLocalized("palkaStatusInactive"))
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(0.45)
                    .foregroundColor(neManager.vpnRunning
                                     ? PalkaDesign.successText
                                     : PalkaDesign.textMuted)

                Spacer()

                Text(neManager.vpnRunning ? "ON" : "OFF")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(PalkaDesign.textMuted)
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(Color.white.opacity(0.05))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.07), lineWidth: 1))
            }

            VStack(alignment: .leading, spacing: 9) {
                Text(neManager.vpnRunning
                     ? palkaLocalized("palkaProtectionOnTitle")
                     : palkaLocalized("palkaProtectionOffTitle"))
                    .font(.system(size: 30, weight: .heavy))
                    .tracking(-1.0)
                    .fixedSize(horizontal: false, vertical: true)

                Text(neManager.vpnRunning
                     ? palkaLocalized("palkaProtectionOnDescription")
                     : palkaLocalized("palkaProtectionOffDescription"))
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(PalkaDesign.textSecondary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: toggleVpn) {
                HStack(spacing: 10) {
                    if connectionActionInFlight {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color.black.opacity(0.78)))
                    } else {
                        Image(systemName: "power")
                            .font(.system(size: 16, weight: .bold))
                    }

                    Text(connectionActionInFlight
                         ? palkaLocalized("palkaPleaseWait")
                         : neManager.vpnRunning
                            ? palkaLocalized("palkaDisconnect")
                            : palkaLocalized("palkaConnect"))
                }
            }
            .buttonStyle(PalkaPrimaryButtonStyle())
            .disabled(connectionActionInFlight)

            HStack(spacing: 0) {
                connectionMetric(
                    title: palkaLocalized("palkaLocalCore"),
                    value: palkaLocalized("palkaOnDevice")
                )

                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 1, height: 34)
                    .padding(.horizontal, 16)

                connectionMetric(
                    title: palkaLocalized("palkaLocalProxy"),
                    value: byeDPIProxyAddr,
                    monospaced: true
                )
            }
        }
        .padding(20)
        .palkaCard(radius: 24, selected: neManager.vpnRunning)
    }

    private func connectionMetric(title: String, value: String, monospaced: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased(with: Locale.current))
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.55)
                .foregroundColor(PalkaDesign.textMuted)

            Text(value)
                .font(.system(size: 12, weight: .semibold, design: monospaced ? .monospaced : .default))
                .foregroundColor(PalkaDesign.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var presetCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 19, weight: .semibold))
                .foregroundColor(PalkaDesign.textPrimary)
                .frame(width: 44, height: 44)
                .background(Color.white.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(palkaLocalized("palkaActivePreset").uppercased(with: Locale.current))
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.55)
                    .foregroundColor(PalkaDesign.textMuted)

                Text(PalkaPreset.name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(PalkaDesign.textPrimary)

                Text(palkaLocalized("palkaPresetScope"))
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(PalkaDesign.textSecondary)
            }

            Spacer(minLength: 8)
        }
        .padding(16)
        .palkaCard(selected: true)
    }

    @ViewBuilder
    private var settingsControl: some View {
        if neManager.vpnRunning {
            Button {
                showAlertType = .vpnEnabledHint
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "lock.fill")
                    Text(palkaLocalized("palkaSettingsLocked"))
                }
            }
            .buttonStyle(PalkaSecondaryButtonStyle())
        } else {
            NavigationLink(destination: SettingsScreen()) {
                HStack(spacing: 10) {
                    Image(systemName: "slider.horizontal.3")
                    Text(R.string.localizable.generalSettings())
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(PalkaDesign.textMuted)
                }
            }
            .buttonStyle(PalkaSecondaryButtonStyle())
        }
    }
    
    fileprivate func toggleVpn() {
        guard !connectionActionInFlight else { return }
        connectionActionInFlight = true

#if DEBUG
        if (ProcessInfo.processInfo.previewMode) {
            if (neManager.vpnRunning) {
                neManager.stopConnection()
                connectionActionInFlight = false
                return
            }
            vpnStartFailErrorText = ""
            neManager.startConnection { success, error in
                connectionActionInFlight = false
            }
            return
        }
#endif
        vpnStartFailErrorText = ""
        if (neManager.vpnRunning) {
            neManager.stopConnection()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                connectionActionInFlight = false
            }
            return
        }
        if (properties.byeDPILaunchConfig.listenIP == "0.0.0.0") {
            lnwPermissionManager.checkAndRequestPermission { status in
                print(status)
            }
        }
        neManager.startConnection { success, error in
            DispatchQueue.main.async {
                self.connectionActionInFlight = false
                if let safeErr = error {
                    if let byedpiErr = safeErr as? BDError {
                        self.vpnStartFailErrorText = byedpiErr.errorDescription
                    } else {
                        self.vpnStartFailErrorText = safeErr.localizedDescription + " (" + String(describing: safeErr) + ")"
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
