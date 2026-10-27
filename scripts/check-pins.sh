#!/bin/sh
# check-pins.sh -- every recipe must carry the pins in pins.env. Prints one line per check;
# exit 0 when all agree, 1 on any mismatch. (The Homebrew tap lives in aien-dev/homebrew-omega and
# has its own copy of this check.)
set -eu
here=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$here"
. ./pins.env
bad=0
need() { # file needle label
  if grep -qF -- "$2" "$1"; then echo "ok   $1 $3"; else echo "FAIL $1 lacks $3 ($2)"; bad=1; fi
}
for f in flake.nix guix/aien/omega.scm aur/PKGBUILD aur/.SRCINFO docker/Dockerfile; do
  need "$f" "$OMEGA_MV_COMMIT" commit
done
for f in flake.nix guix/aien/omega.scm aur/PKGBUILD docker/Dockerfile; do
  need "$f" "$OMC_SHA256" omc-sha256
done
need aur/PKGBUILD "$OMEGA_MV_TARBALL_SHA256" archive-sha256
need aur/.SRCINFO "$OMEGA_MV_TARBALL_SHA256" archive-sha256
need docker/Dockerfile "$OMEGA_MV_TARBALL_SHA256" archive-sha256
need aur/PKGBUILD "pkgver=$OMC_VERSION" version
need aur/.SRCINFO "pkgver = $OMC_VERSION" version
# flake.nix carries the archive hash as SRI and guix as nix-base32; both encode the same 32 bytes.
need flake.nix "sha256-xiG2zv5yjWeholOp2JkUlUBkYNNl3ZHqNWRR6yJUqVw=" archive-sri
need guix/aien/omega.scm "0p59ahifnlb46pm93pb5sdh68h4m2jcxiaaklahng3bjzv7bc8f6" archive-nix32
sri=$(printf '%s' "$OMEGA_MV_TARBALL_SHA256" | xxd -r -p | base64)
[ "sha256-$sri" = "sha256-xiG2zv5yjWeholOp2JkUlUBkYNNl3ZHqNWRR6yJUqVw=" ] \
  && echo "ok   archive-sri decodes to pins.env OMEGA_MV_TARBALL_SHA256" \
  || { echo "FAIL archive-sri does not decode to pins.env OMEGA_MV_TARBALL_SHA256"; bad=1; }
exit $bad
