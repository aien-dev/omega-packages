#!/bin/sh
# omc-from-seed.sh WORKDIR -- fetch the pinned omega-mv source archive, check its sha256, birth omc
# from the 408-byte seed with omega-mv's own seed/omega-from-seed.sh, and check the result's sha256.
#
#   sh scripts/omc-from-seed.sh build          # writes build/omc and keeps build/omega-mv-<commit>/
#
# Environment (used by the negative controls; leave unset for a normal build):
#   EXPECT_SRC_SHA256   expected archive sha256   (default: OMEGA_MV_TARBALL_SHA256 in pins.env)
#   EXPECT_OMC_SHA256   expected omc sha256       (default: OMC_SHA256 in pins.env)
#   SRC_ARCHIVE         use this local archive instead of downloading (it is still hash-checked)
#   TAMPER_SEED=1       flip one hex digit of seed/rung0/seed0.hex before the birth (must FAIL)
#
# Exit 0 = PASS, 1 = FAIL, 2 = usage, 3 = NOT_RUN (not AArch64 Linux).
# Host glue only: curl, tar, gzip, sha256sum. Every byte of omc is written by the seed programs.
set -eu
here=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
. "$here/pins.env"
[ $# -eq 1 ] || { echo "usage: omc-from-seed.sh WORKDIR" >&2; exit 2; }
if [ "$(uname -s)/$(uname -m)" != Linux/aarch64 ]; then
  echo "NOT_RUN: the seed programs are AArch64 Linux ELF files; this host is $(uname -s)/$(uname -m)"
  exit 3
fi
w=$1
mkdir -p "$w"
w=$(CDPATH= cd -- "$w" && pwd)
fail() { printf 'FAIL %s\n' "$*" >&2; exit 1; }

arc=$w/omega-mv-$OMEGA_MV_COMMIT.tar.gz
if [ -n "${SRC_ARCHIVE:-}" ]; then
  cp "$SRC_ARCHIVE" "$arc"
elif [ ! -s "$arc" ]; then
  curl -fsSL --retry 3 -o "$arc" "https://github.com/aien-dev/omega-mv/archive/$OMEGA_MV_COMMIT.tar.gz"
fi
want=${EXPECT_SRC_SHA256:-$OMEGA_MV_TARBALL_SHA256}
got=$(sha256sum "$arc" | cut -d' ' -f1)
[ "$got" = "$want" ] || fail "source archive sha256 $got, pinned $want"
printf 'PASS source archive %s\n' "$got"

tree=$w/omega-mv-$OMEGA_MV_COMMIT
rm -rf "$tree"
tar -xzf "$arc" -C "$w"
[ -f "$tree/seed/omega-from-seed.sh" ] || fail "archive has no seed/omega-from-seed.sh"

if [ "${TAMPER_SEED:-}" = 1 ]; then
  # Negative control: change the first hex word of the hand-written seed. The chain must refuse it.
  f=$tree/seed/rung0/seed0.hex
  cp "$f" "$w/seed0.hex.orig"
  awk 'done!=1 && /^[0-9a-fA-F]/ { c=substr($0,1,1); r=(c=="0")?"1":"0"; $0=r substr($0,2); done=1 } {print}' \
    "$w/seed0.hex.orig" > "$f"
  ! cmp -s "$f" "$w/seed0.hex.orig" || fail "tamper edit changed nothing"
  echo "CONTROL seed0.hex tampered: $(cmp "$f" "$w/seed0.hex.orig" || true)"
fi

(cd "$tree" && sh seed/omega-from-seed.sh) || fail "seed/omega-from-seed.sh refused the tree"
want=${EXPECT_OMC_SHA256:-$OMC_SHA256}
got=$(sha256sum "$tree/seed/out/omc" | cut -d' ' -f1)
[ "$got" = "$want" ] || fail "omc sha256 $got, pinned $want"
cp "$tree/seed/out/omc" "$w/omc"
chmod 0755 "$w/omc"
printf 'PASS omc %s %s bytes\n' "$got" "$(wc -c < "$w/omc" | tr -d ' ')"
