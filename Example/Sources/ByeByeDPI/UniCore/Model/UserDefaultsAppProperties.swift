//
//  UserDefaultsProperties.swift
//  SwByeDPI
//
//  Created by developer on 26.03.2026.
//

import Foundation
import SwByeDPI

final class UserDefaultsAppProperties {
    
    fileprivate static let _appGroupUserDefaults = UserDefaults(suiteName: Constants.APP_GROUP_ID) ?? UserDefaults.standard
    
    static var byeDPIVPNRunning: Bool {
        get {
            return _appGroupUserDefaults.bool(forKey: UserDefaultsAppKeys.byeDPIVPNRunning.rawValue)
        }
    }
    
    static var byeDPIListenIp: String {
        get {
            return _appGroupUserDefaults.string(forKey: UserDefaultsAppKeys.selectedByeDPIListenIpAddrKey.rawValue) ?? SBDConfig.defaultListenIP
        }
        set {
            _appGroupUserDefaults.set(newValue, forKey: UserDefaultsAppKeys.selectedByeDPIListenIpAddrKey.rawValue)
        }
    }
    
    static var byeDPIListenPort: UInt16 {
        get {
            return UInt16(_appGroupUserDefaults.integer(forKey: UserDefaultsAppKeys.selectedByeDPIListenPortKey.rawValue))
        }
        set {
            _appGroupUserDefaults.set(newValue, forKey: UserDefaultsAppKeys.selectedByeDPIListenPortKey.rawValue)
        }
    }
    
    static var byeDPIBufSize: UInt32 {
        get {
            return UInt32(_appGroupUserDefaults.integer(forKey: UserDefaultsAppKeys.selectedByeDPIBufSizeKey.rawValue))
        }
        set {
            _appGroupUserDefaults.set(newValue, forKey: UserDefaultsAppKeys.selectedByeDPIBufSizeKey.rawValue)
        }
    }
    
    static var byeDPIMaxConn: UInt16 {
        get {
            return UInt16(_appGroupUserDefaults.integer(forKey: UserDefaultsAppKeys.selectedByeDPIMaxConn.rawValue))
        }
        set {
            _appGroupUserDefaults.set(newValue, forKey: UserDefaultsAppKeys.selectedByeDPIMaxConn.rawValue)
        }
    }
    
    static var byeDPITTL: UInt8? {
        get {
            guard let _ = _appGroupUserDefaults.object(forKey: UserDefaultsAppKeys.selectedByeDPITTL.rawValue) else {
                return nil
            }
            return UInt8(_appGroupUserDefaults.integer(forKey: UserDefaultsAppKeys.selectedByeDPITTL.rawValue))
        }
        set {
            guard let safeNewValue = newValue else {
                _appGroupUserDefaults.removeObject(forKey: UserDefaultsAppKeys.selectedByeDPITTL.rawValue)
                return
            }
            _appGroupUserDefaults.set(safeNewValue, forKey: UserDefaultsAppKeys.selectedByeDPITTL.rawValue)
        }
    }
    
    static var byeDPIRestrictDomainResolve: Bool {
        get {
            return _appGroupUserDefaults.bool(forKey: UserDefaultsAppKeys.byeDPIRestrictDomainResolve.rawValue)
        }
        set {
            _appGroupUserDefaults.set(newValue, forKey: UserDefaultsAppKeys.byeDPIRestrictDomainResolve.rawValue)
        }
    }
    
    static var byeDPIRestrictUDP: Bool {
        get {
            return _appGroupUserDefaults.bool(forKey: UserDefaultsAppKeys.byeDPIRestrictUDP.rawValue)
        }
        set {
            _appGroupUserDefaults.set(newValue, forKey: UserDefaultsAppKeys.byeDPIRestrictUDP.rawValue)
        }
    }
    
    static var byeDPILogLevel: UInt8? {
        get {
            guard let _ = _appGroupUserDefaults.object(forKey: UserDefaultsAppKeys.selectedbyeDPILogLevel.rawValue) else {
                return nil
            }
            return UInt8(_appGroupUserDefaults.integer(forKey: UserDefaultsAppKeys.selectedbyeDPILogLevel.rawValue))
        }
        set {
            guard let safeNewValue = newValue else {
                _appGroupUserDefaults.removeObject(forKey: UserDefaultsAppKeys.selectedbyeDPILogLevel.rawValue)
                return
            }
            _appGroupUserDefaults.set(safeNewValue, forKey: UserDefaultsAppKeys.selectedbyeDPILogLevel.rawValue)
        }
    }
    
    static var byeDPICmdArgs: [String] {
        get {
            return (_appGroupUserDefaults.array(forKey: UserDefaultsAppKeys.selectedByeDPICmdArgsKey.rawValue) as? [String]) ?? []
        }
        set {
            _appGroupUserDefaults.set(newValue, forKey: UserDefaultsAppKeys.selectedByeDPICmdArgsKey.rawValue)
        }
    }
    
    static var resolvedDnsServers: [String] {
        get {
            return (_appGroupUserDefaults.array(forKey: UserDefaultsAppKeys.resolvedDnsServersKey.rawValue) as? [String]) ?? []
        }
        set {
            _appGroupUserDefaults.set(newValue, forKey: UserDefaultsAppKeys.resolvedDnsServersKey.rawValue)
        }
    }
    
    static var dnsOverAddr: String {
        get {
            return _appGroupUserDefaults.string(forKey: UserDefaultsAppKeys.selectedDnsOverAddrKey.rawValue) ?? "8.8.8.8"
        }
        set {
            _appGroupUserDefaults.set(newValue, forKey: UserDefaultsAppKeys.selectedDnsOverAddrKey.rawValue)
        }
    }
    
    static var tunMtu: UInt16 {
        get {
            return UInt16(_appGroupUserDefaults.integer(forKey: UserDefaultsAppKeys.selectedTunMtuKey.rawValue))
        }
        set {
            _appGroupUserDefaults.set(newValue, forKey: UserDefaultsAppKeys.selectedTunMtuKey.rawValue)
        }
    }

    static var activeStrategyName: String {
        get {
            return _appGroupUserDefaults.string(
                forKey: UserDefaultsAppKeys.activeStrategyName.rawValue
            ) ?? PalkaPreset.name
        }
        set {
            _appGroupUserDefaults.set(
                newValue,
                forKey: UserDefaultsAppKeys.activeStrategyName.rawValue
            )
        }
    }

    static var activeStrategyID: String {
        get {
            return _appGroupUserDefaults.string(
                forKey: UserDefaultsAppKeys.activeStrategyID.rawValue
            ) ?? PalkaPreset.id
        }
        set {
            _appGroupUserDefaults.set(
                newValue,
                forKey: UserDefaultsAppKeys.activeStrategyID.rawValue
            )
        }
    }

    static var activeStrategyTemplateArgs: [String] {
        get {
            return (_appGroupUserDefaults.array(
                forKey: UserDefaultsAppKeys.activeStrategyTemplateArgs.rawValue
            ) as? [String]) ?? PalkaPreset.recommendedTemplateArgs
        }
        set {
            _appGroupUserDefaults.set(
                newValue,
                forKey: UserDefaultsAppKeys.activeStrategyTemplateArgs.rawValue
            )
        }
    }

    static var selectedServiceIDs: [String] {
        get {
            return (_appGroupUserDefaults.array(
                forKey: UserDefaultsAppKeys.selectedServiceIDs.rawValue
            ) as? [String]) ?? PalkaService.defaultIDs
        }
        set {
            _appGroupUserDefaults.set(
                newValue,
                forKey: UserDefaultsAppKeys.selectedServiceIDs.rawValue
            )
        }
    }

    static var customServiceDomains: [String] {
        get {
            return (_appGroupUserDefaults.array(
                forKey: UserDefaultsAppKeys.customServiceDomains.rawValue
            ) as? [String]) ?? []
        }
        set {
            _appGroupUserDefaults.set(
                PalkaService.sanitizedCustomDomains(newValue),
                forKey: UserDefaultsAppKeys.customServiceDomains.rawValue
            )
        }
    }

    static var smartRecoveryEnabled: Bool {
        get { _appGroupUserDefaults.bool(forKey: UserDefaultsAppKeys.smartRecoveryEnabled.rawValue) }
        set { _appGroupUserDefaults.set(newValue, forKey: UserDefaultsAppKeys.smartRecoveryEnabled.rawValue) }
    }

    static var onDemandEnabled: Bool {
        get { _appGroupUserDefaults.bool(forKey: UserDefaultsAppKeys.onDemandEnabled.rawValue) }
        set { _appGroupUserDefaults.set(newValue, forKey: UserDefaultsAppKeys.onDemandEnabled.rawValue) }
    }

    static var onDemandWiFiEnabled: Bool {
        get {
            guard _appGroupUserDefaults.object(forKey: UserDefaultsAppKeys.onDemandWiFiEnabled.rawValue) != nil else {
                return true
            }
            return _appGroupUserDefaults.bool(forKey: UserDefaultsAppKeys.onDemandWiFiEnabled.rawValue)
        }
        set { _appGroupUserDefaults.set(newValue, forKey: UserDefaultsAppKeys.onDemandWiFiEnabled.rawValue) }
    }

    static var onDemandCellularEnabled: Bool {
        get {
            guard _appGroupUserDefaults.object(forKey: UserDefaultsAppKeys.onDemandCellularEnabled.rawValue) != nil else {
                return true
            }
            return _appGroupUserDefaults.bool(forKey: UserDefaultsAppKeys.onDemandCellularEnabled.rawValue)
        }
        set { _appGroupUserDefaults.set(newValue, forKey: UserDefaultsAppKeys.onDemandCellularEnabled.rawValue) }
    }

    static var networkProfiles: [PalkaNetworkProfile] {
        get {
            guard let data = _appGroupUserDefaults.data(forKey: UserDefaultsAppKeys.networkProfiles.rawValue) else {
                return []
            }
            return (try? JSONDecoder().decode([PalkaNetworkProfile].self, from: data)) ?? []
        }
        set {
            _appGroupUserDefaults.set(
                try? JSONEncoder().encode(newValue),
                forKey: UserDefaultsAppKeys.networkProfiles.rawValue
            )
        }
    }
    
    fileprivate init() {}
    
}
