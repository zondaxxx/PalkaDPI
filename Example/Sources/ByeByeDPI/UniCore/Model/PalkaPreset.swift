//
//  PalkaPreset.swift
//  PalkaDPI
//
//  A conservative, local-only preset built only from primitives available in
//  the Apple ByeDPI build. Flowseal's raw-packet tricks are intentionally not
//  represented here because iOS cannot provide WinDivert/NFQUEUE semantics.
//

import Foundation

enum PalkaPreset {
    static let id = "builtin.multisplit.v3"
    static let name = "PalkaDPI Multisplit"

    static let catalogTargetsPlaceholder = "{palka_targets}"
    static var hostsArgument: String {
        PalkaService.targetsArgument(for: PalkaService.defaultIDs)
    }

    /// Strategy groups:
    /// 1. Split the target TLS ClientHello into several ordinary TCP writes.
    /// 2. Morph clear-text HTTP requests for the same selected hosts.
    /// 3. The final empty group passes all unmatched traffic through normally.
    ///
    /// UDP fake groups are deliberately absent from the offline fallback. The
    /// signed online catalog carries the real Flowseal QUIC/Discord payloads;
    /// sending the engine's default 64 zero bytes was ineffective.
    static let recommendedTemplateArgs: [String] = [
        "-Kt,h", catalogTargetsPlaceholder, "-s1", "-s1+s", "-s3+s", "-s6+s", "-An",
        "-Kh", catalogTargetsPlaceholder, "-Mh,d,r", "-s1+h", "-An",
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
