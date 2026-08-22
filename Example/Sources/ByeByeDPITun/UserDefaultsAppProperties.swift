import Foundation

final class UserDefaultsAppProperties {
    
    fileprivate static let _appGroupUserDefaults = UserDefaults(suiteName: Constants.APP_GROUP_ID) ?? UserDefaults.standard
    
    static var byeDPIVPNRunning: Bool {
        get {
            return _appGroupUserDefaults.bool(forKey: UserDefaultsAppKeys.byeDPIVPNRunning.rawValue)
        }
        set {
            _appGroupUserDefaults.set(newValue, forKey: UserDefaultsAppKeys.byeDPIVPNRunning.rawValue)
        }
    }

    static var tunnelRuntimeLogs: Data? {
        get {
            return _appGroupUserDefaults.data(forKey: UserDefaultsAppKeys.tunnelRuntimeLogs.rawValue)
        }
        set {
            _appGroupUserDefaults.set(newValue, forKey: UserDefaultsAppKeys.tunnelRuntimeLogs.rawValue)
        }
    }
    
    fileprivate init() {}
    
}
