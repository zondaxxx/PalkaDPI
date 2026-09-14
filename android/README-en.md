<div align="center">
  <p>
    <img src="https://github.com/romanvht/ByeDPIAndroid/raw/master/.github/images/app.svg" alt="Логотип ByeDPI" width="200" />
  </p>
  <h1>ByeByeDPI Android</h1>
  <p>
    <a href="README.md">Русский</a> |
    English |
    <a href="README-tr.md">Türkçe</a>
  </p>
  <p>
    <a href="https://github.com/romanvht/ByeByeDPI/releases/latest"><img src="https://img.shields.io/github/v/release/romanvht/ByeByeDPI" alt="Latest Release" /></a>
    <a href="https://github.com/romanvht/ByeByeDPI/releases"><img src="https://img.shields.io/github/downloads/romanvht/ByeByeDPI/total" alt="Downloads" /></a>
    <a href="https://github.com/romanvht/ByeByeDPI/blob/master/LICENSE"><img src="https://img.shields.io/github/license/romanvht/ByeByeDPI" alt="License" /></a>
    <a href="https://github.com/romanvht/ByeByeDPI"><img src="https://img.shields.io/github/languages/code-size/romanvht/ByeByeDPI" alt="GitHub code size in bytes"/></a>
  </p>
</div>

An Android application that runs ByeDPI locally and redirects all traffic through it.

For stable operation, you may need to adjust the settings. More information about the available options can be found in the [ByeDPI documentation](https://github.com/hufrea/byedpi/blob/main/README.md).

This application is not a VPN. It uses Android’s VPN mode to redirect traffic, but it does not send any data to a remote server. It does not encrypt your traffic or hide your IP address.

The application has only one official website:
https://byebyedpi.xyz

---

### Features

* Automatically starts the service when the device boots
* Saves command-line parameter lists
* Improved compatibility with Android TV/BOX devices
* Per-app split tunneling
* Settings import and export

### Usage

* Enable the corresponding option in the settings to use automatic startup.
* It is recommended to connect to the VPN once in order to accept the permission request.
* After that, the application will automatically start the service when the device boots, depending on the selected mode: VPN or Proxy.
* Comprehensive community guide: [ByeByeDPI-Manual](https://byebyedpi.xyz)

### Building

1. Clone the repository with its submodules:

```bash
git clone --recurse-submodules
```

2. Run the build script from the repository root:

```bash
./gradlew assembleRelease
```

3. The APK will be located in:
   `app/build/outputs/apk/release/`

> Note: hev_socks5_tunnel cannot be built on Windows. You will need to use WSL.

### Signing Certificate Hash

SHA-256:
`77:45:10:75:AC:EA:40:64:06:47:5D:74:D4:59:88:3A:49:A6:40:51:FA:F3:2E:42:F7:18:F3:F9:77:7A:8D:FB`

### Dependencies

* [ByeDPI](https://github.com/hufrea/byedpi)
* [hev-socks5-tunnel](https://github.com/heiher/hev-socks5-tunnel)

### Acknowledgements

* [hufrea](https://github.com/hufrea) — for [ByeDPI](https://github.com/hufrea/byedpi)
* [dovecoteescapee](https://github.com/dovecoteescapee) — for the original implementation of [ByeDPIAndroid](https://github.com/dovecoteescapee/ByeDPIAndroid)
