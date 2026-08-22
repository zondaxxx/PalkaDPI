# PalkaDPI for iOS

PalkaDPI is a local, system-wide DPI bypass prototype for iOS 14 and newer. It
uses `NEPacketTunnelProvider`, `Tun2SocksKit`, and the native ByeDPI core. No
remote VPN server is used: outbound connections leave directly from the phone.

The shipped preset only modifies traffic for Discord and YouTube domains. It
uses TCP/TLS splitting, reordered writes, TLS-record fragmentation, and small
UDP prefixes on the common Discord voice ranges. Other traffic is passed
through without a DPI strategy.

## What you need to sign it

A certificate alone is not enough for the VPN target. Your Apple Developer
account must also have identifiers and provisioning profiles for:

- Host app: `<your bundle id>`
- Packet Tunnel extension: `<your bundle id>.tun`
- App Group: for example `group.<your bundle id>`
- Network Extensions capability with `packet-tunnel-provider`
- App Groups capability

Use the same App Group in both provisioning profiles. A paid Apple Developer
Program membership is normally required for the packet-tunnel entitlement.

## Build and run from Xcode

1. Install full Xcode and open `SwByeDPI.xcodeproj`.
2. Select the `ByeByeDPI` scheme.
3. In Signing & Capabilities, choose your Team for both `ByeByeDPI` and
   `ByeByeDPITun`.
4. Replace `PALKA_BUNDLE_ID` and `PALKA_APP_GROUP` in both targets with your
   registered values. The extension ID is generated as
   `$(PALKA_BUNDLE_ID).tun`.
5. Connect the iPhone, select it as the destination, and press Run.
6. On first start, tap the power button and accept the iOS VPN configuration.

You can also archive from Terminal without editing the project:

```bash
xcodebuild \
  -project SwByeDPI.xcodeproj \
  -scheme ByeByeDPI \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath packages/PalkaDPI.xcarchive \
  -allowProvisioningUpdates \
  archive \
  DEVELOPMENT_TEAM=YOUR_TEAM_ID \
  PALKA_BUNDLE_ID=your.unique.palkadpi \
  PALKA_APP_GROUP=group.your.unique.palkadpi
```

## Build an unsigned IPA

With full Xcode selected:

```bash
PALKA_BUNDLE_ID=your.unique.palkadpi \
PALKA_APP_GROUP=group.your.unique.palkadpi \
./scripts/build_unsigned_ipa.sh
```

The result is `packages/PalkaDPI-unsigned.ipa`. When signing manually, sign the
embedded `ByeByeDPITun.appex` first and the host app second. Both signatures
must contain the same App Group; the extension must retain the
`packet-tunnel-provider` entitlement.

## Test checklist

1. Test on a physical device (the iOS simulator cannot validate the tunnel).
2. Verify ordinary sites still work before testing blocked resources.
3. Test YouTube playback in Safari and in the YouTube app on Wi-Fi and cellular.
4. Test Discord login, messages, media, and a voice channel separately.
5. If TCP access fails for your ISP, open Settings -> Strategy checker, test the
   Discord/YouTube lists, and apply the result from Strategy analyzer.

## Known limits

- This is not a byte-for-byte port of Flowseal/zapret. iOS does not expose
  WinDivert, NFQUEUE, arbitrary raw TCP injection, or per-app VPN selection to a
  normal developer-signed app.
- QUIC uses UDP/443 and cannot be filtered by SNI with this core. Clients usually
  fall back to TCP/TLS, but the delay varies. Blocking all UDP would make the
  fallback faster while breaking games, calls, and other UDP apps, so the
  default preset does not do that.
- DPI strategies depend on the ISP. The included strategy is a conservative
  starting point, not a universal guarantee.
- iOS 15 or newer is recommended because Network Extension has a larger memory
  allowance than older releases.

## License and provenance

This project is derived from
[mIwr/SwByeDPI](https://github.com/mIwr/SwByeDPI), which embeds
[hufrea/byedpi](https://github.com/hufrea/byedpi). The combined source is
distributed under the included AGPL-3.0 license; the embedded byedpi core keeps
its upstream MIT license notice.
