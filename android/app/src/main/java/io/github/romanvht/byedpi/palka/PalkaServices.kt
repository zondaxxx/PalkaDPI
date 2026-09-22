package io.github.romanvht.byedpi.palka

/**
 * Services PalkaDPI targets. Mirrors PalkaService in the iOS app so the same
 * signed catalog template (`{palka_targets}`) resolves to the same host list
 * and the same probes decide whether a strategy "works".
 */
data class PalkaService(
    val id: String,
    val name: String,
    val probeUrl: String,
    /** Text the probe body must contain; null accepts any 2xx from the right host. */
    val marker: String?,
    val domains: List<String>,
    /**
     * Larger object on a filtered domain. TSPU often lets a TLS handshake and a
     * few KB through and then freezes the flow, so a 256 KB Range download on
     * the real delivery host is what separates "connects" from "works".
     */
    val bulkUrl: String? = null
)

object PalkaServices {
    const val TARGETS_PLACEHOLDER = "{palka_targets}"

    val all: List<PalkaService> = listOf(
        PalkaService(
            "discord", "Discord", "https://discord.com/api/v10/gateway", "gateway.discord.gg",
            listOf(
                "dis.gd", "discord-activities.com", "discord.app", "discord.co",
                "discord.com", "discord.design", "discord.dev", "discord.gg",
                "discord.gift", "discord.gifts", "discord.media", "discord.new",
                "discord.store", "discord.tools", "discordactivities.com",
                "discordapp.com", "discordapp.net", "discordcdn.com",
                "discordmerch.com", "discordpartygames.com", "discordsays.com",
                "discordsez.com"
            ),
            "https://discord.com/"
        ),
        PalkaService(
            "youtube", "YouTube", "https://www.youtube.com/robots.txt", "robots.txt file for YouTube",
            listOf(
                "ggpht.com", "googleapis.com", "googleusercontent.com",
                "googlevideo.com", "returnyoutubedislikeapi.com", "youtu.be",
                "youtube-nocookie.com", "youtube.com", "youtubekids.com",
                "yt.be", "ytimg.com"
            ),
            "https://i.ytimg.com/vi/dQw4w9WgXcQ/maxresdefault.jpg"
        ),
        PalkaService(
            "instagram", "Instagram", "https://www.instagram.com/robots.txt", "Instagram",
            listOf("cdninstagram.com", "instagram.com", "instagram.net"),
            "https://www.instagram.com/"
        ),
        PalkaService(
            "tiktok", "TikTok", "https://www.tiktok.com/robots.txt", "User-agent:",
            listOf(
                "byteoversea.com", "ibytedtos.com", "ibyteimg.com", "muscdn.com",
                "musical.ly", "sgpstatp.com", "tiktok.com", "tiktokcdn.com",
                "tiktokcdn-us.com", "tiktokv.com"
            ),
            "https://www.tiktok.com/"
        ),
        PalkaService(
            "x", "X / Twitter", "https://x.com/robots.txt", "Google / Bing Search Engine Robots",
            listOf("t.co", "twimg.com", "twitter.com", "x.com")
        ),
        PalkaService(
            "telegram", "Telegram", "https://telegram.org/", "Telegram Messenger",
            listOf("t.me", "telegram.dog", "telegram.me", "telegram.org"),
            "https://telegram.org/img/t_logo_2x.png"
        ),
    )

    /** Same default as iOS: the recommended preset targets Discord + YouTube. */
    val defaultIds: List<String> = listOf("discord", "youtube")

    fun selected(ids: Collection<String>): List<PalkaService> {
        val picked = all.filter { it.id in ids }
        return picked.ifEmpty { all.filter { it.id in defaultIds } }
    }

    fun sanitizedCustomDomains(raw: List<String>): List<String> = raw.mapNotNull { value ->
        var v = value.trim().lowercase()
        v.indexOf("://").takeIf { it >= 0 }?.let { v = v.substring(it + 3) }
        v = v.substringBefore('/').trim('.')
        v.takeIf {
            it.length in 3..253 && it.contains('.') &&
                it.all { c -> c in 'a'..'z' || c in '0'..'9' || c == '-' || c == '.' }
        }
    }.distinct().take(100)

    /** `-H:` host whitelist argument for the selected services plus custom domains. */
    fun targetsArgument(ids: Collection<String>, customDomains: List<String> = emptyList()): String {
        val domains = LinkedHashSet<String>()
        selected(ids).forEach { domains.addAll(it.domains) }
        domains.addAll(sanitizedCustomDomains(customDomains))
        return "-H:" + domains.joinToString(" ")
    }

    /** Selected services plus one plain HTTPS probe per custom domain. */
    fun diagnosticTargets(ids: Collection<String>, customDomains: List<String>): List<PalkaService> =
        selected(ids) + sanitizedCustomDomains(customDomains).map {
            PalkaService("custom:$it", it, "https://$it/", null, listOf(it))
        }
}

/** The offline fallback strategy, identical to PalkaPreset on iOS. */
object PalkaPreset {
    const val ID = "builtin.multisplit.v3"
    const val NAME = "PalkaDPI Multisplit"

    val recommendedTemplate: List<String> = listOf(
        "-Kt,h", PalkaServices.TARGETS_PLACEHOLDER, "-s1", "-s1+s", "-s3+s", "-s6+s", "-An",
        "-Kh", PalkaServices.TARGETS_PLACEHOLDER, "-Mh,d,r", "-s1+h", "-An",
    )

    /** Leading group that silently drops QUIC (UDP/443) so HTTP/3 clients fall back to TCP. */
    val quicDropGroup: List<String> = listOf("-Ku", "-V443", "--udp-drop", "-An")

    fun resolve(
        template: List<String>,
        serviceIds: Collection<String>,
        customDomains: List<String>,
        blockQuic: Boolean
    ): List<String> {
        val targets = PalkaServices.targetsArgument(serviceIds, customDomains)
        val resolved = template.map { if (it == PalkaServices.TARGETS_PLACEHOLDER) targets else it }
        if (!blockQuic || resolved.isEmpty() || resolved.contains("--udp-drop")) return resolved
        return quicDropGroup + resolved
    }

    /** One command line for `byedpi_cmd_args`; arguments with spaces are quoted for shellSplit. */
    fun commandLine(args: List<String>): String = args.joinToString(" ") { arg ->
        if (arg.any { it.isWhitespace() }) "\"" + arg.replace("\"", "") + "\"" else arg
    }
}
