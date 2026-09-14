package io.github.romanvht.byedpi.palka

/**
 * Services PalkaDPI targets. Mirrors PalkaService in the iOS app so the same
 * signed catalog template (`{palka_targets}`) resolves to the same host list.
 */
data class PalkaService(
    val id: String,
    val name: String,
    val probeUrl: String,
    val domains: List<String>
)

object PalkaServices {
    const val TARGETS_PLACEHOLDER = "{palka_targets}"

    val all: List<PalkaService> = listOf(
        PalkaService(
            "discord", "Discord", "https://discord.com/api/v10/gateway",
            listOf(
                "dis.gd", "discord-activities.com", "discord.app", "discord.co",
                "discord.com", "discord.design", "discord.dev", "discord.gg",
                "discord.gift", "discord.gifts", "discord.media", "discord.new",
                "discord.store", "discord.tools", "discordactivities.com",
                "discordapp.com", "discordapp.net", "discordcdn.com",
                "discordmerch.com", "discordpartygames.com", "discordsays.com",
                "discordsez.com"
            )
        ),
        PalkaService(
            "youtube", "YouTube", "https://www.youtube.com/robots.txt",
            listOf(
                "ggpht.com", "googleapis.com", "googleusercontent.com",
                "googlevideo.com", "returnyoutubedislikeapi.com", "youtu.be",
                "youtube-nocookie.com", "youtube.com", "youtubekids.com",
                "yt.be", "ytimg.com"
            )
        ),
        PalkaService(
            "instagram", "Instagram", "https://www.instagram.com/robots.txt",
            listOf("cdninstagram.com", "instagram.com", "instagram.net")
        ),
        PalkaService(
            "tiktok", "TikTok", "https://www.tiktok.com/robots.txt",
            listOf(
                "byteoversea.com", "ibytedtos.com", "ibyteimg.com", "muscdn.com",
                "musical.ly", "sgpstatp.com", "tiktok.com", "tiktokcdn.com",
                "tiktokcdn-us.com", "tiktokv.com"
            )
        ),
        PalkaService(
            "x", "X / Twitter", "https://x.com/robots.txt",
            listOf("t.co", "twimg.com", "twitter.com", "x.com")
        ),
        PalkaService(
            "telegram", "Telegram", "https://telegram.org/",
            listOf("t.me", "telegram.dog", "telegram.me", "telegram.org")
        ),
    )

    val defaultIds: Set<String> = all.map { it.id }.toSet()

    fun selected(ids: Set<String>): List<PalkaService> {
        val picked = all.filter { it.id in ids }
        return if (picked.isEmpty()) all else picked
    }

    /** `-H:` host whitelist argument for the selected services plus custom domains. */
    fun targetsArgument(ids: Set<String>, customDomains: List<String> = emptyList()): String {
        val domains = LinkedHashSet<String>()
        selected(ids).forEach { domains.addAll(it.domains) }
        customDomains.map { it.trim().lowercase() }
            .filter { it.length in 3..253 && it.contains('.') && it.all { c -> c.isLetterOrDigit() || c == '-' || c == '.' } }
            .forEach { domains.add(it) }
        return "-H:" + domains.joinToString(" ")
    }
}
