# omega-packages

Install `omc`, the Omega compiler, the way you already install software: Nix, Guix, Arch (AUR),
Debian/Ubuntu `.deb`, a container image, or Homebrew. Every one of these recipes builds the same thing
the same way: it starts from a **408-byte hand-written seed**, climbs `seed0 → hex1 → asm2 → om4 → omc`,
lets `omc` rebuild itself until two generations are byte-identical, and then refuses the result unless
its sha256 is exactly

```
2c82480596bbdc50cda9626866209ef662d5834f278f839ff4ce0250c495029f  omc  (325524 bytes)
```

No C compiler, assembler or linker writes a byte of it. The build needs only `sh`, `printf`, `cat`,
`stat`, `sed`, `sha256sum` and `cmp`; the container recipe does it with BusyBox alone. If you care
about trusting your toolchain, I think that is worth five minutes of your time.

**Honest limits.** `omc` runs on and emits code for **AArch64 (arm64) Linux only**. On x86_64 you can
run it under `qemu-aarch64` user emulation, and the programs it produces are AArch64 ELF files too. The
version is `0.0.0+git.e5b32567` because omega-mv has not tagged a release yet; it means "the compiler
at omega-mv commit `e5b32567`".

## Install

Latest release: <https://github.com/aien-dev/omega-packages/releases/tag/v0.0.0-git.e5b32567>

**Debian / Ubuntu (arm64)**

```sh
v=0.0.0-git.e5b32567; u=https://github.com/aien-dev/omega-packages/releases/download/v$v
curl -fsSLO "$u/omc_0.0.0+git.e5b32567-1_arm64.deb" -O "$u/SHA256SUMS"
sha256sum -c --ignore-missing SHA256SUMS
sudo dpkg -i omc_0.0.0+git.e5b32567-1_arm64.deb
```

**Container (linux/arm64)** — the image is `FROM scratch` with one file, `/omc`:

```sh
docker run --rm -i ghcr.io/aien-dev/omc:0.0.0-git.e5b32567 < hello.om > hello && chmod +x hello && ./hello
```

**Nix (aarch64-linux, flakes)**

```sh
nix run github:aien-dev/omega-packages < hello.om > hello && chmod +x hello && ./hello
nix build github:aien-dev/omega-packages#omc
```

**Guix (aarch64-linux)** — from a clone, or add the channel:

```sh
git clone https://github.com/aien-dev/omega-packages && cd omega-packages
guix build -L guix omc
```

```scheme
;; ~/.config/guix/channels.scm
(cons (channel (name 'aien) (url "https://github.com/aien-dev/omega-packages") (branch "main"))
      %default-channels)
```

**Arch Linux ARM** — `aur/PKGBUILD` (not on the AUR yet):

```sh
git clone https://github.com/aien-dev/omega-packages && cd omega-packages/aur && makepkg -si
```

**Homebrew on Linux arm64** — [aien-dev/homebrew-omega](https://github.com/aien-dev/homebrew-omega):

```sh
brew install --build-from-source aien-dev/omega/omc
```

**Try it** with [`examples/hello.om`](examples/hello.om), which sums 1..10 and prints `omega 55`:

```sh
omc < hello.om > hello && chmod +x hello && ./hello
```

## Checking what you got

Every release file and the container image carry a GitHub artifact attestation (SLSA build
provenance), and the bare binary carries an SPDX SBOM listing the source archive and each seed input
with its sha256:

```sh
gh attestation verify omc-linux-arm64 --repo aien-dev/omega-packages
gh attestation verify oci://ghcr.io/aien-dev/omc:0.0.0-git.e5b32567 --repo aien-dev/omega-packages
```

Better still, rebuild it yourself and compare: `sh scripts/omc-from-seed.sh build` on any arm64 Linux
box prints `PASS omc 2c8248…029f` or refuses.

## How the recipes are checked

[`recipes`](.github/workflows/ci.yml) runs on GitHub's `ubuntu-24.04-arm` runners on every push: the
seed build plus `.deb` install, `nix build`/`nix run`, `guix build`, `makepkg` inside Arch Linux ARM,
and the container build. Each recipe also has a negative control that must fail: a tampered seed byte,
a wrong expected hash, a changed source archive, a drifted pin. A dispatch with
`control=tampered-seed` makes the main build job go red on purpose.

| file | what it is |
| --- | --- |
| `pins.env` | omega-mv commit, source-archive sha256, omc sha256, version |
| `scripts/omc-from-seed.sh` | fetch + check archive, run `seed/omega-from-seed.sh`, check omc |
| `scripts/check-pins.sh` | every recipe carries the pins in `pins.env` |
| `scripts/sbom.sh` | SPDX 2.3 SBOM on stdout |
| `debian/` | `.deb` assembly (`dpkg-deb`) |
| `flake.nix` | `packages.aarch64-linux.omc`, `apps.aarch64-linux.omc` |
| `.guix-channel`, `guix/aien/omega.scm` | Guix channel with package `omc` |
| `aur/` | `PKGBUILD` and `.SRCINFO` |
| `docker/Dockerfile` | `ghcr.io/aien-dev/omc` |

## Connected repos

- Parent: [aien-dev/omega-mv](https://github.com/aien-dev/omega-mv), pinned at `e5b32567a7aff3ce594e3254a622a846a6cd190b` (the language, the compiler and the seed chain live there).
- [aien-dev/homebrew-omega](https://github.com/aien-dev/homebrew-omega): the Homebrew tap.
- [aien-dev/omega-seed-challenge](https://github.com/aien-dev/omega-seed-challenge): rebuild the chain yourself and check every rung's hash.

## Foreign dependencies

These are packaging glue, not part of Omega. None of them writes a byte of `omc`.

| dependency | version | what it does here |
| --- | --- | --- |
| POSIX sh, printf, cat, stat, sed, sha256sum, cmp | host's (GNU coreutils / BusyBox 1.37.0) | run the seed chain; check hashes |
| curl, tar, gzip | host's | fetch and unpack the pinned source archive |
| dpkg-deb | Ubuntu 24.04's | assemble the `.deb` |
| Nix + nixpkgs | nixpkgs `3ec63636` (flake.lock) | `stdenvNoCC` shell environment for the flake |
| GNU Guix | 1.4.0 (Ubuntu 24.04 package, in CI) | `gnu-build-system` shell environment |
| makepkg / pacman | Arch Linux ARM (`menci/archlinuxarm`, in CI) | AUR package build |
| BusyBox | `busybox:1.37.0-musl` (digest-pinned) | the container's build stage |
| spdx-tools | 0.8.3 (CI) | validates the SBOM |
| GitHub Actions: checkout, upload/download-artifact, attest-build-provenance, attest-sbom, docker/*, cachix/install-nix-action | tags in the workflows | CI and release |

The Omega replacement for the glue that matters (fetch, unpack, hash) is Omega's own toolchain growing
those words; the hash checks stay as outside oracles on purpose, since a checker built by the chain it
checks would be circular.

## License

Apache-2.0 WITH LLVM-exception (see `LICENSE`). omega-mv itself is Apache-2.0.
