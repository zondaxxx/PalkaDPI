//
//  NEObservablleManager.swift
//  SwByeDPI
//
//  Created by developer on 06.03.2026.
//

import SwiftUI
import CoreFoundation
import NetworkExtension

fileprivate func handleByeDPIVpnStart(notificationCenter: CFNotificationCenter?, observer: UnsafeMutableRawPointer?, notificationName: CFNotificationName?, object: UnsafeRawPointer?, info: CFDictionary?) {
    //UserDefaultsAppProperties.appGroupUserDefaults.set(true, forKey: UserDefaultsAppKeys.byeDPIVPNRunning.rawValue)
    DispatchQueue.main.async {
        NotificationCenter.default.post(name: .BBDVpnStarted, object: nil)
    }
}

fileprivate func handleByeDPIVpnStop(notificationCenter: CFNotificationCenter?, observer: UnsafeMutableRawPointer?, notificationName: CFNotificationName?, object: UnsafeRawPointer?, info: CFDictionary?) {
    //UserDefaultsAppProperties.appGroupUserDefaults.set(false, forKey: UserDefaultsAppKeys.byeDPIVPNRunning.rawValue)
    DispatchQueue.main.async {
        NotificationCenter.default.post(name: .BBDVpnStopped, object: nil)
    }
}

@available(tvOS 17.0, *)
class NEObservableManager: ObservableObject {
    
    @Published fileprivate(set) var neTunnelProviderManager: NETunnelProviderManager?
    @Published fileprivate(set) var vpnRunning: Bool
    
    fileprivate let _cfNotificationCenter: CFNotificationCenter
    fileprivate var _startVpnObserver: UnsafeRawPointer?
    fileprivate var _stopVpnObserver: UnsafeRawPointer?
    
    init(initCompletion: @escaping (NETunnelProviderManager?, (any Error)?) -> Void) {
        neTunnelProviderManager = nil
        vpnRunning = UserDefaultsAppProperties.byeDPIVPNRunning
        _cfNotificationCenter = CFNotificationCenterGetDarwinNotifyCenter()
        _startVpnObserver = nil
        _stopVpnObserver = nil
        
        NotificationCenter.default.addObserver(forName: .BBDVpnStarted, object: nil, queue: .main, using: handleVpnStart)
        NotificationCenter.default.addObserver(forName: .BBDVpnStopped, object: nil, queue: .main, using: handleVpnStop)
        
        
        _startVpnObserver = UnsafeRawPointer(Unmanaged.passUnretained(self).toOpaque())
        _stopVpnObserver = UnsafeRawPointer(Unmanaged.passUnretained(self).toOpaque())
        CFNotificationCenterAddObserver(_cfNotificationCenter, _startVpnObserver, handleByeDPIVpnStart, CFNotificationName.byeDPIVpnStarted.rawValue, nil, .deliverImmediately)
        CFNotificationCenterAddObserver(_cfNotificationCenter, _stopVpnObserver, handleByeDPIVpnStop, CFNotificationName.byeDPIVpnStopped.rawValue, nil, .deliverImmediately)
        getOrInitNEManager(completion: initCompletion)
    }
    
    deinit {
        CFNotificationCenterRemoveEveryObserver(_cfNotificationCenter, _startVpnObserver)
        CFNotificationCenterRemoveEveryObserver(_cfNotificationCenter, _stopVpnObserver)
        NotificationCenter.default.removeObserver(self, name: .BBDVpnStarted, object: nil)
        NotificationCenter.default.removeObserver(self, name: .BBDVpnStopped, object: nil)
    }
    
    func startConnection(completion: @escaping (_ success: Bool, _ error: Error?) -> Void) {
#if DEBUG
        if (ProcessInfo.processInfo.previewMode) {
            //Disable real VPN connection for preview
            vpnRunning = true
            return
        }
#endif
        if let safeManager = neTunnelProviderManager {
            startConnection(manager: safeManager, completion: completion)
            return
        }
        getOrInitNEManager { manager, err in
            guard let safeManager = manager else {
                return
            }
            self.startConnection(manager: safeManager, completion: completion)
        }
    }
    
    func stopConnection() {
#if DEBUG
        if (ProcessInfo.processInfo.previewMode) {
            //Disable real VPN connection for preview
            vpnRunning = false
            return
        }
#endif
        if let safeManager = neTunnelProviderManager {
            vpnRunning = NEObservableManager.isVpnRunning(status: safeManager.connection.status)
            safeManager.connection.stopVPNTunnel()
            return
        }
        getOrInitNEManager { manager, err in
            guard let safeManager = manager else {
                return
            }
            self.vpnRunning = NEObservableManager.isVpnRunning(status: safeManager.connection.status)
            safeManager.connection.stopVPNTunnel()
        }
    }
    
    fileprivate func startConnection(manager: NETunnelProviderManager, completion: @escaping (_ success: Bool, _ error: Error?) -> Void) {
        manager.loadFromPreferences { loadErr in
            if let safeLoadErr = loadErr {
                if (self.vpnRunning) {
                    self.vpnRunning = false
                }
                completion(false, safeLoadErr)
                return
            }
            let firstTimeVpnSet = manager.protocolConfiguration == nil
            let startTunnelOptions = NEUtil.generateConnectionParamsFromAppUserDefaults()
            manager.isEnabled = true
            let vpnProtocol = NETunnelProviderProtocol()
            vpnProtocol.providerConfiguration = startTunnelOptions
            vpnProtocol.serverAddress = UserDefaultsAppProperties.byeDPIListenIp
            vpnProtocol.providerBundleIdentifier = Constants.VPN_PROVIDER_BUNDLE_ID
            vpnProtocol.includeAllNetworks = false
            if #available(iOS 16.4, *) {
                vpnProtocol.excludeAPNs = true
            }
            if #available(iOS 14.2, *) {
                vpnProtocol.excludeLocalNetworks = true
                vpnProtocol.enforceRoutes = false
            }
            if #available(iOS 17.4, *) {
                vpnProtocol.excludeDeviceCommunication = true
            }
            manager.protocolConfiguration = vpnProtocol
            self.applyOnDemandPreferences(to: manager)
            manager.saveToPreferences { saveErr in
                if let safeSaveErr = saveErr {
                    if (self.vpnRunning) {
                        self.vpnRunning = false
                    }
                    completion(false, safeSaveErr)
                    return
                }
                if (firstTimeVpnSet) {
                    //Load after the first save
                    self.startConnection(manager: manager, completion: completion)
                    return
                }
                do {
                    try manager.connection.startVPNTunnel(options: startTunnelOptions)
                    self.vpnRunning = true
                    completion(true, nil)
                } catch {
#if DEBUG
                    print("Start VPN error")
                    print(error)
#endif
                    if (self.vpnRunning) {
                        self.vpnRunning = false
                    }
                    completion(false, error)
                }
            }
        }
    }

    func configureOnDemand(
        enabled: Bool,
        includeWiFi: Bool,
        includeCellular: Bool,
        completion: @escaping (Error?) -> Void
    ) {
        UserDefaultsAppProperties.onDemandEnabled = enabled
        UserDefaultsAppProperties.onDemandWiFiEnabled = includeWiFi
        UserDefaultsAppProperties.onDemandCellularEnabled = includeCellular

        getOrInitNEManager { manager, error in
            guard let manager = manager else {
                completion(error)
                return
            }
            manager.loadFromPreferences { loadError in
                guard loadError == nil else {
                    completion(loadError)
                    return
                }
                self.applyOnDemandPreferences(to: manager)
                manager.saveToPreferences(completionHandler: completion)
            }
        }
    }

    private func applyOnDemandPreferences(to manager: NETunnelProviderManager) {
        let enabled = UserDefaultsAppProperties.onDemandEnabled
        var rules: [NEOnDemandRule] = []
        if enabled && UserDefaultsAppProperties.onDemandWiFiEnabled {
            let rule = NEOnDemandRuleConnect()
            rule.interfaceTypeMatch = .wiFi
            rules.append(rule)
        }
        if enabled && UserDefaultsAppProperties.onDemandCellularEnabled {
            let rule = NEOnDemandRuleConnect()
            rule.interfaceTypeMatch = .cellular
            rules.append(rule)
        }
        manager.onDemandRules = rules
        manager.isOnDemandEnabled = enabled && !rules.isEmpty
    }
    
    fileprivate func getOrInitNEManager(completion: @escaping (NETunnelProviderManager?, (any Error)?) -> Void) {
        if let safeManager = neTunnelProviderManager {
            vpnRunning = NEObservableManager.isVpnRunning(status: safeManager.connection.status)
            completion(safeManager, nil)
            return
        }
        NETunnelProviderManager.loadAllFromPreferences { managers, error in
            if let safeError = error {
                print(safeError)
                completion(nil, error)
                return
            }
            guard let safeManagers = managers else {
                print("NE Tunnel Provider managers array from cache is nil - Init the new one")
                let manager = NETunnelProviderManager()
                self.neTunnelProviderManager = manager
                if (self.vpnRunning) {
                    self.vpnRunning = false
                }
                completion(manager, nil)
                return
            }
            if (safeManagers.isEmpty) {
                print("NE Tunnel Provider managers array from cache is empty -> Init the new one")
                let manager = NETunnelProviderManager()
                self.neTunnelProviderManager = manager
                if (self.vpnRunning) {
                    self.vpnRunning = false
                }
                completion(manager, nil)
                return
            }
            self.neTunnelProviderManager = safeManagers[0]
            self.vpnRunning = NEObservableManager.isVpnRunning(status: safeManagers[0].connection.status)
            completion(safeManagers[0], nil)
        }
    }
    
    fileprivate func handleVpnStart(_ notification: Notification) {
        if (vpnRunning) {
            return
        }
        vpnRunning = true
    }
    
    fileprivate func handleVpnStop(_ notification: Notification) {
        if (!vpnRunning) {
            return
        }
        vpnRunning = false
    }
    
    fileprivate static func isVpnRunning(status: NEVPNStatus) -> Bool {
        switch (status) {
        case .connected: return true
        case .connecting: return false
        case .disconnecting: return false
        case .disconnected: return false
        case .invalid: return false
        case .reasserting: return false
        @unknown default:
            print("Unknown NEVPNStatus status")
            print(status)
            return false
        }
    }
}
