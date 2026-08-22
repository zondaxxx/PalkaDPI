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

    /// Only these second-level domains are subjected to TCP/TLS desync.
    /// Everything else reaches the network without payload manipulation.
    static let targetDomains: [String] = [
        "dis.gd",
        "discord-activities.com",
        "discord.app",
        "discord.co",
        "discord.com",
        "discord.design",
        "discord.dev",
        "discord.gg",
        "discord.gift",
        "discord.gifts",
        "discord.media",
        "discord.new",
        "discord.store",
        "discord.tools",
        "discordactivities.com",
        "discordapp.com",
        "discordapp.net",
        "discordcdn.com",
        "discordmerch.com",
        "discordpartygames.com",
        "discordsays.com",
        "discordsez.com",
        "ggpht.com",
        "googleapis.com",
        "googleusercontent.com",
        "googlevideo.com",
        "returnyoutubedislikeapi.com",
        "youtu.be",
        "youtube-nocookie.com",
        "youtube.com",
        "youtubekids.com",
        "yt.be",
        "ytimg.com",
    ]

    static let catalogTargetsPlaceholder = "{palka_targets}"
    static let hostsArgument = "-H:" + targetDomains.joined(separator: " ")

    /// Strategy groups:
    /// 1. Split and reorder the target TLS ClientHello.
    /// 2. If a reset/redirect/TLS error is detected, fragment the SNI into a
    ///    separate TLS record and TCP write.
    /// 3. Send harmless UDP prefixes on the common Discord voice ranges.
    /// 4. The final empty group passes all unmatched traffic through normally.
    static let recommendedCommandArgs: [String] = [
        "-Kt,h", hostsArgument, "-s1", "-d3+s", "-At,r,s",
        "-Kt,h", hostsArgument, "-r1+s", "-s1+s", "-An",
        "-Ku", "-V19294-19344", "-a6", "-An",
        "-Ku", "-V50000-50100", "-a6", "-An",
    ]
}
