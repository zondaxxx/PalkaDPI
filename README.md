<p align="center">
  <img src="./RepoAssets/palka-banner.svg" width="100%" alt="PalkaDPI for iOS" />
</p>

<p align="center">
  <a href="https://github.com/zondaxxx/BVDPI-IOS/actions/workflows/build-release.yml"><img src="https://github.com/zondaxxx/BVDPI-IOS/actions/workflows/build-release.yml/badge.svg" alt="Build and Release" /></a>
  <a href="https://github.com/zondaxxx/BVDPI-IOS/releases/latest"><img src="https://img.shields.io/github/v/release/zondaxxx/BVDPI-IOS?color=ffffff&label=release&labelColor=09090d" alt="Latest release" /></a>
  <a href="./LICENSE"><img src="https://img.shields.io/badge/license-AGPL--3.0-ffffff?labelColor=09090d" alt="AGPL-3.0" /></a>
  <img src="https://img.shields.io/badge/iOS-14%2B-ffffff?labelColor=09090d" alt="iOS 14+" />
</p>

# PalkaDPI

Простое iOS-приложение для локального обхода DPI. Оно поднимает системный
`NEPacketTunnelProvider`, направляет трафик через локальный SOCKS-туннель и
обрабатывает его ядром ByeDPI прямо на iPhone. Внешний VPN-сервер не используется.

> PalkaDPI не скрывает IP-адрес, не меняет страну и не добавляет VPN-шифрование.
> VPN-профиль iOS нужен только для системной маршрутизации трафика в локальное ядро.

## Возможности

- одно понятное действие «Подключить» на главном экране;
- встроенный профиль Discord + YouTube;
- онлайн-каталог стратегий с поиском, кэшем и применением в один тап;
- отображение HTTP-отклика Discord и YouTube через текущее подключение;
- локальная работа без аккаунтов, аналитики и удалённого VPN-сервера;
- отдельный экспертный раздел для DNS, прокси, доменных списков и диагностики;
- русский и английский интерфейс;
- автоматическая сборка проверенного unsigned IPA через GitHub Actions.

## Быстрый старт

1. Скачайте [последний unsigned IPA](https://github.com/zondaxxx/BVDPI-IOS/releases/latest/download/PalkaDPI-unsigned.ipa).
2. Подпишите сначала `ByeByeDPITun.appex`, затем основное приложение.
3. Установите IPA на физический iPhone.
4. Нажмите «Подключить» и разрешите добавление VPN-конфигурации.
5. Если встроенный профиль не работает, откройте «Настройки → Стратегии из интернета» и выберите другой.

Для подписи нужны provisioning profiles с одинаковым App Group и entitlement
`com.apple.developer.networking.networkextension = packet-tunnel-provider`.
Одного сертификата разработчика недостаточно.

Подробная инструкция: [PALKA-README.md](./PALKA-README.md).

## Онлайн-стратегии

Приложение загружает [strategy-catalog.json](./strategy-catalog.json) напрямую из
этого репозитория по HTTPS. Каталог можно обновлять без перевыпуска IPA.

Перед применением PalkaDPI проверяет версию схемы, размер документа, уникальность
ID, HTTPS-ссылки на источники, количество и длину аргументов. Команды дополнительно
проходят встроенную проверку совместимости ByeDPI с Apple-платформами. Последний
успешно загруженный каталог доступен офлайн.

Как добавить профиль: [docs/STRATEGY-CATALOG.md](./docs/STRATEGY-CATALOG.md).

## Отклик сервисов

Главный экран измеряет время небольшого HTTPS-запроса к официальным доменам
Discord и YouTube. Это HTTP round trip, а не ICMP-ping: обычное iOS-приложение не
может отправлять произвольные ICMP-пакеты. При активном туннеле запрос проходит
через текущую конфигурацию PalkaDPI.

## Сборка

```bash
git clone https://github.com/zondaxxx/BVDPI-IOS.git
cd BVDPI-IOS
open SwByeDPI.xcodeproj
```

Выберите схему `ByeByeDPI`, укажите Team, Bundle ID и App Group для приложения и
Packet Tunnel extension. Для unsigned IPA с полным Xcode:

```bash
PALKA_BUNDLE_ID=your.unique.palkadpi \
PALKA_APP_GROUP=group.your.unique.palkadpi \
./scripts/build_unsigned_ipa.sh
```

Результат: `packages/PalkaDPI-unsigned.ipa`.

## Структура

```text
Example/Sources/ByeByeDPI/       iOS-приложение и SwiftUI
Example/Sources/ByeByeDPITun/    Packet Tunnel extension
Sources/ByeDPIC/                 встроенное C-ядро byedpi
Sources/ByeDPIKit/               Swift-обёртка над ядром
Sources/SwByeDPI/                модели, списки и диагностика
strategy-catalog.json            обновляемый онлайн-каталог
scripts/                         сборка и валидация
```

## Происхождение проекта

PalkaDPI — производная работа от [mIwr/SwByeDPI](https://github.com/mIwr/SwByeDPI)
с ядром [hufrea/byedpi](https://github.com/hufrea/byedpi). Идея простого профиля
для Discord и YouTube вдохновлена [Flowseal/zapret-discord-youtube](https://github.com/Flowseal/zapret-discord-youtube),
но Windows-компоненты zapret и WinDivert в приложение не входят.

Полный перечень встроенного кода, зависимостей, источников доменных списков,
транзитивных проектов и лицензий находится в
[ACKNOWLEDGEMENTS.md](./ACKNOWLEDGEMENTS.md).

## Ограничения

- эффективность стратегии зависит от сети, оператора и текущего способа фильтрации;
- iOS не предоставляет WinDivert/NFQUEUE и произвольную raw TCP-инъекцию;
- QUIC/UDP 443 нельзя фильтровать по SNI тем же способом, что TCP/TLS;
- тестировать туннель нужно на физическом устройстве;
- используйте приложение только в соответствии с применимым законодательством.

## Лицензия

Проект распространяется по [AGPL-3.0](./LICENSE). Встроенное ядро byedpi сохраняет
свою MIT-лицензию в [Sources/ByeDPIC/byedpi/LICENSE](./Sources/ByeDPIC/byedpi/LICENSE).
