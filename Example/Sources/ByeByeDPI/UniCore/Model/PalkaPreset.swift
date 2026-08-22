//
//  PalkaPreset.swift
//  PalkaDPI
//
//  A conservative, local-only preset inspired by the target lists used by
//  Flowseal/zapret. Apple platforms cannot use WinDivert/nfqws, so ByeDPI
//  performs the equivalent work at the SOCKS/TLS layer.
//

import Foundation

enum PalkaPreset {
    static let name = "Discord + YouTube"

    static let catalogTargetsPlaceholder = "{palka_targets}"
    static var hostsArgument: String {
        PalkaService.targetsArgument(for: PalkaService.defaultIDs)
    }

    /// Strategy groups:
    /// 1. Split and reorder the target TLS ClientHello.
    /// 2. If a reset/redirect/TLS error is detected, fragment the SNI into a
    ///    separate TLS record and TCP write.
    /// 3. Send harmless UDP prefixes on the common Discord voice ranges.
    /// 4. The final empty group passes all unmatched traffic through normally.
    static let recommendedTemplateArgs: [String] = [
        "-Kt,h", catalogTargetsPlaceholder, "-s1", "-d3+s", "-At,r,s",
        "-Kt,h", catalogTargetsPlaceholder, "-r1+s", "-s1+s", "-An",
        "-Ku", "-V19294-19344", "-a6", "-An",
        "-Ku", "-V50000-50100", "-a6", "-An",
    ]

    static var recommendedCommandArgs: [String] {
        resolve(template: recommendedTemplateArgs, serviceIDs: PalkaService.defaultIDs)
    }

    static func resolve(
        template: [String],
        serviceIDs: [String],
        customDomains: [String] = []
    ) -> [String] {
        let targets = PalkaService.targetsArgument(for: serviceIDs, customDomains: customDomains)
        return template.map { $0 == catalogTargetsPlaceholder ? targets : $0 }
    }
}
