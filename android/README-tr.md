<div align="center">
  <p>
    <img src="https://github.com/romanvht/ByeDPIAndroid/raw/master/.github/images/app.svg" alt="Логотип ByeDPI" width="200" />
  </p>
  <h1>ByeByeDPI Android</h1>
  <p>
    <a href="README.md">Русский</a> |
    <a href="README-en.md">English</a> |
    Türkçe
  </p>
  <p>
    <a href="https://github.com/romanvht/ByeByeDPI/releases/latest"><img src="https://img.shields.io/github/v/release/romanvht/ByeByeDPI" alt="Latest Release" /></a>
    <a href="https://github.com/romanvht/ByeByeDPI/releases"><img src="https://img.shields.io/github/downloads/romanvht/ByeByeDPI/total" alt="Downloads" /></a>
    <a href="https://github.com/romanvht/ByeByeDPI/blob/master/LICENSE"><img src="https://img.shields.io/github/license/romanvht/ByeByeDPI" alt="License" /></a>
    <a href="https://github.com/romanvht/ByeByeDPI"><img src="https://img.shields.io/github/languages/code-size/romanvht/ByeByeDPI" alt="GitHub code size in bytes"/></a>
  </p>
</div>

ByeDPI’yi yerel olarak çalıştıran ve tüm trafiği üzerinden yönlendiren bir Android uygulaması.

Kararlı çalışması için ayarların değiştirilmesi gerekebilir. Çeşitli ayarlar hakkında daha fazla bilgiyi [ByeDPI belgelerinde](https://github.com/hufrea/byedpi/blob/main/README.md) bulabilirsiniz.

Bu uygulama bir VPN değildir. Trafiği yönlendirmek için Android’in VPN modunu kullanır, ancak hiçbir veriyi uzak bir sunucuya göndermez. Trafiği şifrelemez ve IP adresinizi gizlemez.

Uygulamanın tek resmî web sitesi:
https://byebyedpi.xyz

---

### Özellikler

* Cihaz açıldığında hizmeti otomatik başlatma
* Komut satırı parametre listelerini kaydetme
* Android TV/BOX ile geliştirilmiş uyumluluk
* Uygulama bazında bölünmüş tünelleme
* Ayarları içe ve dışa aktarma

### Kullanım

* Otomatik başlatmanın çalışması için ayarlardaki ilgili seçeneği etkinleştirin.
* İzin isteğini kabul etmek için VPN bağlantısını en az bir kez başlatmanız önerilir.
* Bundan sonra uygulama, cihaz açıldığında ayarlara bağlı olarak hizmeti VPN veya Proxy modunda otomatik olarak başlatır.
* Topluluk tarafından hazırlanan kapsamlı kılavuz: [ByeByeDPI-Manual](https://byebyedpi.xyz)

### Derleme

1. Depoyu alt modüllerle birlikte klonlayın:

```bash
git clone --recurse-submodules
```

2. Derleme betiğini deponun kök dizininden çalıştırın:

```bash
./gradlew assembleRelease
```

3. APK dosyası şu dizinde bulunacaktır:
   `app/build/outputs/apk/release/`

> Not: hev_socks5_tunnel Windows üzerinde derlenemez. WSL kullanmanız gerekir.

### İmza Özeti

SHA-256:
`77:45:10:75:AC:EA:40:64:06:47:5D:74:D4:59:88:3A:49:A6:40:51:FA:F3:2E:42:F7:18:F3:F9:77:7A:8D:FB`

### Bağımlılıklar

* [ByeDPI](https://github.com/hufrea/byedpi)
* [hev-socks5-tunnel](https://github.com/heiher/hev-socks5-tunnel)

### Teşekkürler

* [hufrea](https://github.com/hufrea) — [ByeDPI](https://github.com/hufrea/byedpi) için
* [dovecoteescapee](https://github.com/dovecoteescapee) — [ByeDPIAndroid](https://github.com/dovecoteescapee/ByeDPIAndroid) uygulamasının ilk sürümü için
