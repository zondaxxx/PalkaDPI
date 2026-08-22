# CHANGELOG

## PalkaDPI 0.4.3

### 22.08.2026

- Added an independent hard deadline to every HTTP probe so a dead packet tunnel cannot stall automatic selection
- Replaced zero-filled UDP fakes with the current Flowseal QUIC and Discord payloads
- Added inline hex payload support to the embedded Apple ByeDPI build
- Rebuilt the signed catalog as six distinct iOS strategies and revoked all ineffective v1/v2 profiles
- Migrated installed v1/v2 configurations to a safe native multisplit fallback
- Replaced the inherited app icon with the PalkaDPI packet-split mark
- Renamed user-facing engine, proxy, editor, tunnel, and analyzer labels to PalkaDPI
- Added exact Flowseal/bol-van payload attribution, checksums, and MIT license text

## PalkaDPI 0.4.2

### 22.08.2026

- Fixed automatic selection starting probes before the system VPN had connected
- Wait for real NetworkExtension `connected` and `disconnected` states instead of fixed delays
- Show whether auto-selection is stopping, connecting, or probing through the tunnel
- Added explicit start/stop timeouts and surfaced lifecycle errors
- Fixed manual and network-profile reconnection flows to wait for actual VPN state transitions

## PalkaDPI 0.4.1

### 22.08.2026

- Replaced ineffective v1 presets with independent upstream iOS-compatible strategies
- Added QUIC/UDP 443 fallback variants
- Require expected official service response content during automatic selection
- Reject HTTP error responses and cross-host block-page redirects
- Fixed the Telegram diagnostic endpoint

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
