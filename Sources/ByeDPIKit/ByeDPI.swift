//
//  ByeDPI.swift
//  ByeDPIKit
//
//  Created by developer on 09.02.2026.
//

import Foundation
#if canImport(ByeDPIC)
import ByeDPIC
#elseif canImport(ByeDPICLib)
import ByeDPICLib
#endif

/// ByeDPI Swift wrapper
open class ByeDPI {
    
    /// ByeDPI version
    public static let versionCode = "0.17.3"
    
    /// ByeDPI proxy started and running flag
    public static var proxyStarted: Bool {
        get {
            return proxy_running() == 1
        }
    }
    
    /// ByeDPI worker thread
    nonisolated(unsafe) fileprivate static var _dpiThread: Thread?
    
#if DEBUG
    /// ByeDPI worker thread (Unit-tests purposes)
    nonisolated(unsafe) static fileprivate(set) var testableDpiThread: Thread?
#endif
    
    /// Starts ByeDPI proxy in current thread
    /// - Parameter args: byedpi launch args
    /// - Returns: byedpi launch status code. For success start (status code = 0) will be no return becouse of byedpi proxy event loop
    public static func startSync(args: [String]) -> Int32 {
        if (proxyStarted) {
            return -1
        }
        // getopt expects argv[0] to be the process name. Passing the first real
        // option there silently skipped it (normally the listener address).
        let processArgs = ["byedpi"] + args
        let argc = Int32(clamping: processArgs.count)
        let utf8CStrings = processArgs.map { $0.utf8CString }
        var allocatedStrings: [UnsafeMutablePointer<CChar>] = []
        for utf8CString in utf8CStrings {
            let pointer = UnsafeMutablePointer<CChar>.allocate(capacity: utf8CString.count)
            utf8CString.withUnsafeBytes { buffer in
                pointer.initialize(from: buffer.bindMemory(to: CChar.self).baseAddress!, count: utf8CString.count)
            }
            allocatedStrings.append(pointer)
        }
            
        let argv = UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>.allocate(capacity: processArgs.count + 1)
        for (index, pointer) in allocatedStrings.enumerated() {
            argv.advanced(by: index).pointee = pointer
        }
            
        argv.advanced(by: processArgs.count).pointee = nil
            
        defer {
            allocatedStrings.forEach { $0.deallocate() }
            argv.deallocate()
        }
        return start_proxy(argc, argv)
    }
    
    /// Starts ByDPI proxy in new thread
    /// - Parameters:
    ///   - args: byedpi launch args
    ///   - startErrCompletion: byedpi launch error completion handler with. Error includes launch status code
    public static func start(args: [String], startErrCompletion: @Sendable @escaping (BDError) -> Void) {
        if (proxyStarted) {
            startErrCompletion(.alreadyRunning)
            return
        }
        let processArgs = ["byedpi"] + args
        let argc = Int32(clamping: processArgs.count)
        let thread = Thread {
            let utf8CStrings = processArgs.map { $0.utf8CString }
            var allocatedStrings: [UnsafeMutablePointer<CChar>] = []
            for utf8CString in utf8CStrings {
                let pointer = UnsafeMutablePointer<CChar>.allocate(capacity: utf8CString.count)
                utf8CString.withUnsafeBytes { buffer in
                    pointer.initialize(from: buffer.bindMemory(to: CChar.self).baseAddress!, count: utf8CString.count)
                }
                allocatedStrings.append(pointer)
            }
                
            let argv = UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>.allocate(capacity: processArgs.count + 1)
            for (index, pointer) in allocatedStrings.enumerated() {
                argv.advanced(by: index).pointee = pointer
            }
                
            argv.advanced(by: processArgs.count).pointee = nil
                
            defer {
                allocatedStrings.forEach { $0.deallocate() }
                argv.deallocate()
            }
            let startRes = start_proxy(argc, argv)
            if (startRes == 0) {
                return
            }
            startErrCompletion(.startError(errCode: Int(startRes)))
        }
        thread.name = "ByeDPI(ciadpi)"
        _dpiThread = thread
#if DEBUG
        testableDpiThread = thread
#endif
        thread.start()
    }
    
#if swift(>=5.5)
    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    public static func start(args: [String]) async -> BDError? {
        if (proxyStarted) {
            return .alreadyRunning
        }
        let processArgs = ["byedpi"] + args
        let argc = Int32(clamping: processArgs.count)
        let startTask = Task {
            nonisolated(unsafe) var err: BDError? = nil
            let thread = Thread {
                let utf8CStrings = processArgs.map { $0.utf8CString }
                var allocatedStrings: [UnsafeMutablePointer<CChar>] = []
                for utf8CString in utf8CStrings {
                    let pointer = UnsafeMutablePointer<CChar>.allocate(capacity: utf8CString.count)
                    utf8CString.withUnsafeBytes { buffer in
                        pointer.initialize(from: buffer.bindMemory(to: CChar.self).baseAddress!, count: utf8CString.count)
                    }
                    allocatedStrings.append(pointer)
                }
                    
                let argv = UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>.allocate(capacity: processArgs.count + 1)
                for (index, pointer) in allocatedStrings.enumerated() {
                    argv.advanced(by: index).pointee = pointer
                }
                    
                argv.advanced(by: processArgs.count).pointee = nil
                    
                defer {
                    allocatedStrings.forEach { $0.deallocate() }
                    argv.deallocate()
                }
                let startRes = start_proxy(argc, argv)
                if (startRes != 0) {
                    err = .startError(errCode: Int(startRes))
                }
            }
            thread.name = "ByeDPI(ciadpi)"
            _dpiThread = thread
#if DEBUG
            testableDpiThread = thread
#endif
            thread.start()
            let oneSecInNanos: UInt64 = 1_000_000_000
            try? await Task.sleep(nanoseconds: oneSecInNanos)
            return err
        }
        let startErr = await startTask.value
        return startErr
    }
#endif
    
    /// byedpi proxy stop
    /// Sends the fake SOCKS Hello and closes server_fd
    /// - Returns: byedpi stop status code
    public static func stop() -> Int32 {
        let stopRes = stop_proxy()
        _dpiThread = nil
        return stopRes
    }
    
    /// byedpi proxy stop
    /// Closes server_fd only
    /// - Returns: byedpi stop status code
    public static func forceStop() -> Int32 {
        let stopRes = stop_proxy_tun()
        _dpiThread = nil
        return stopRes
    }
    
    fileprivate init() {}
}
