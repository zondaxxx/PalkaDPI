# CHANGELOG

## PalkaDPI 0.4.0

### 22.08.2026

- Automatic strategy selection and per-network profiles
- Discord, YouTube, Instagram, TikTok, X/Twitter, Telegram, and custom targets
- Multi-sample DNS/TLS/HTTP diagnostics and smart recovery
- On Demand rules for Wi-Fi and cellular
- Signed Ed25519 strategy catalog with compatibility, revocation, and rollback
- Search, favorites, application history, and local success statistics
- WidgetKit status widget and Siri/Shortcuts actions
- Privacy-preserving support report

## Version 0.17.3

### 10.04.2026

**Library changes**

- Added new test domains (Google Meet, AI, Play)
- Added new strategies (Retrieved from TG channels)
- Ephemeral HTTP/SOCKS proxy URLSession support
- byedpi (C) updater

**Example app changes**

- NE VPN status notifier (CFNotificationCenter)
- VPN start from system settings fix - use protocolConfiguration
- Multiple alert view modifies show fix
- Strategy test result card view update
- Use .id view modifier for list item views
- Static library build support (XCode) for leverage App Store Connect nested frameworks restriction (BBD: SwByeDPI - ByeDPIKit - ByeDPIC; BBDTun: ByeDPIKit - ByeDPIC)

### 01.04.2026

- Initial release
