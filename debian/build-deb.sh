#!/bin/sh
# build-deb.sh OMC OUTDIR -- package an already hash-checked omc (scripts/omc-from-seed.sh) as
# OUTDIR/omc_<version>-1_arm64.deb. Binary package only, assembled with dpkg-deb; the build itself
# is the seed chain, which needs no compiler, so there is no debhelper source package.
set -eu
here=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
. "$here/pins.env"
[ $# -eq 2 ] || { echo "usage: build-deb.sh OMC OUTDIR" >&2; exit 2; }
omc=$1 out=$2
got=$(sha256sum "$omc" | cut -d' ' -f1)
[ "$got" = "$OMC_SHA256" ] || { echo "FAIL omc sha256 $got, pinned $OMC_SHA256" >&2; exit 1; }
ver=$OMC_VERSION-1
mkdir -p "$out"
root=$(mktemp -d)
trap 'rm -rf "$root"' EXIT
install -Dm0755 "$omc" "$root/usr/bin/omc"
install -Dm0644 "$here/LICENSE" "$root/usr/share/doc/omc/copyright"
install -Dm0644 "$here/examples/hello.om" "$root/usr/share/doc/omc/examples/hello.om"
mkdir -p "$root/DEBIAN"
size=$(du -sk "$root/usr" | cut -f1)
sed -e "s/@VERSION@/$ver/" -e "s/@SIZE@/$size/" -e "s/@COMMIT@/$OMEGA_MV_COMMIT/" \
  -e "s/@OMC_SHA256@/$OMC_SHA256/" "$here/debian/control.in" > "$root/DEBIAN/control"
deb=$out/omc_${ver}_arm64.deb
SOURCE_DATE_EPOCH=${SOURCE_DATE_EPOCH:-0} dpkg-deb --root-owner-group -Zxz --build "$root" "$deb" >/dev/null
echo "$deb"
