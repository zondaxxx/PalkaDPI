//
//  UserDefaultsKeys.swift
//  SwByeDPI
//
//  Created by developer on 11.03.2026.
//

enum UserDefaultsAppKeys: String {
    
    case byeDPIVPNRunning = "byedpiVPNRunning"
    case selectedByeDPIListenIpAddrKey = "byedpiListenIpAddr"
    case selectedByeDPIListenPortKey = "byedpiListenPort"
    case selectedByeDPIBufSizeKey = "byedpiBufSize"
    case selectedByeDPIMaxConn = "byedpiMaxConn"
    case selectedByeDPITTL = "byedpiTTL"
    case byeDPIRestrictDomainResolve = "byedpiNoDomain"
    case byeDPIRestrictUDP = "byedpiNoUDP"
    case selectedbyeDPILogLevel = "byedpiLogLevel"
    case selectedByeDPICmdArgsKey = "byedpiCmdArgs"
    case resolvedDnsServersKey = "resolvedDnsServers"
    case selectedDnsOverAddrKey = "dnsOverAddr"
    case selectedTunMtuKey = "tunMtu"
    case activeStrategyName = "activeStrategyName"
    case activeStrategyID = "activeStrategyID"
    case activeStrategyTemplateArgs = "activeStrategyTemplateArgs"
    case selectedServiceIDs = "selectedServiceIDs"
    case customServiceDomains = "customServiceDomains"
    case smartRecoveryEnabled = "smartRecoveryEnabled"
    case onDemandEnabled = "onDemandEnabled"
    case onDemandWiFiEnabled = "onDemandWiFiEnabled"
    case onDemandCellularEnabled = "onDemandCellularEnabled"
    case networkProfiles = "networkProfiles"
    
}
