# PalkaDPI for Android

Android-версия PalkaDPI: локальный обход DPI без внешнего VPN-сервера. Это форк
[romanvht/ByeDPIAndroid](https://github.com/romanvht/ByeDPIAndroid) (GPL-3.0) с ядром
[hufrea/byedpi](https://github.com/hufrea/byedpi) и hev-socks5-tunnel, плюс:

- **Каталог PalkaDPI** (меню ⋮ → «Каталог PalkaDPI»): тот же Ed25519-подписанный
  `strategy-catalog.json`, что и в iOS-версии. Подпись проверяется на устройстве
  встроенным публичным ключом, кэш хранится в `filesDir`.
- **Применение в один тап**: стратегия каталога превращается в командную строку ByeDPI
  (`{palka_targets}` → `-H:` со списком доменов Discord/YouTube/Instagram/TikTok/X/Telegram)
  и сохраняется в историю команд.
- **Автоподбор по каталогу**: весь каталог загружается в встроенный тестер стратегий
  как пользовательский список, тестер сам перезапускает ядро и сортирует по проценту ответов.
- **Блокировка QUIC** (переключатель, по умолчанию включена): группа
  `-Ku -V443 --udp-drop -An` добавляется первой, HTTP/3-клиенты сразу уходят на TCP.
- Ядро byedpi вшито в репозиторий (`app/src/main/cpp/byedpi`, upstream `ba53229`) с
  патчем PalkaDPI из `PalkaDPI/patches/byedpi/0001-palkadpi-core.patch`
  (`-l hex:` бинарные фейки, `-k/--udp-drop`).

## Сборка

```bash
export JAVA_HOME=/usr/local/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home
export ANDROID_HOME=/usr/local/share/android-commandlinetools   # нужны ndk;27.x и cmake;3.22.1
./gradlew assembleDebug
```

APK: `app/build/outputs/apk/debug/app-universal-debug.apk` (и по ABI рядом).

Внутренний Kotlin-пакет и JNI-имена оставлены как в upstream (`io.github.romanvht.byedpi`),
изменён только `applicationId` (`io.github.zondaxxx.palkadpi`), чтобы приложение
ставилось рядом с оригинальным ByeByeDPI. Код PalkaDPI лежит в
`app/src/main/java/io/github/romanvht/byedpi/palka/`.
