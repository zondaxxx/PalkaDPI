# PalkaDPI byedpi core patches

`update_byedpi.sh` re-clones upstream `hufrea/byedpi` from scratch, so every
PalkaDPI change to the core lives here as a unified diff and is re-applied
after the clone. Never edit `Sources/ByeDPIC/byedpi/*` without regenerating
the patch.

Current patch set (`0001-palkadpi-core.patch`):

- `-l hex:<data>` inline binary fake payloads (signed catalog QUIC/Discord decoys);
- `-k, --udp-drop` per-group UDP drop (`-Ku -V443 --udp-drop -An` forces QUIC
  clients onto TCP where the TLS desync groups apply).

Regenerate after editing the core:

```bash
git clone --depth 1 https://github.com/hufrea/byedpi /tmp/byedpi-up
mv /tmp/byedpi-up/main.c /tmp/byedpi-up/ciadpi_main.c
sed -i "" "s|#define DAEMON|//#define DAEMON|g" /tmp/byedpi-up/ciadpi_main.c
for f in ciadpi_main.c params.h desync.c; do
  diff -u /tmp/byedpi-up/$f Sources/ByeDPIC/byedpi/$f | sed "1s|.*|--- a/$f|;2s|.*|+++ b/$f|"
done > patches/byedpi/0001-palkadpi-core.patch
```
