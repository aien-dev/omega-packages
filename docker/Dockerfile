# syntax=docker/dockerfile:1.7
# ghcr.io/aien-dev/omc -- omc born from the 408-byte seed inside BusyBox, shipped FROM scratch.
# The build stage uses BusyBox sh, printf, sed, stat, cmp and sha256sum to run omega-mv's
# seed/omega-from-seed.sh; nothing else touches the bytes. linux/arm64 only.
#   docker run --rm -i ghcr.io/aien-dev/omc:0.0.0-git.e5b32567 < hello.om > hello
ARG OMEGA_MV_COMMIT=e5b32567a7aff3ce594e3254a622a846a6cd190b
ARG OMC_SHA256=2c82480596bbdc50cda9626866209ef662d5834f278f839ff4ce0250c495029f

FROM --platform=linux/arm64 busybox:1.37.0-musl@sha256:5cec3fc171c87218698e85a52af7087de727372aae264a787b8112901a5b0092 AS seed
ARG OMEGA_MV_COMMIT
ARG OMC_SHA256
ADD --checksum=sha256:c621b6cefe728d67a1a253a9d8991495406460d365dd91ea356451eb2254a95c \
    https://github.com/aien-dev/omega-mv/archive/e5b32567a7aff3ce594e3254a622a846a6cd190b.tar.gz /src.tar.gz
RUN set -eu; tar -xzf /src.tar.gz -C /; cd "/omega-mv-$OMEGA_MV_COMMIT"; \
    sh seed/omega-from-seed.sh; \
    echo "$OMC_SHA256  seed/out/omc" | sha256sum -c -; \
    cp seed/out/omc /omc

FROM scratch
ARG OMEGA_MV_COMMIT
LABEL org.opencontainers.image.source="https://github.com/aien-dev/omega-packages" \
      org.opencontainers.image.description="omc, the Omega compiler, born from a 408-byte seed (stdin .om -> stdout AArch64 ELF)" \
      org.opencontainers.image.licenses="Apache-2.0" \
      org.opencontainers.image.revision="${OMEGA_MV_COMMIT}"
COPY --from=seed /omc /omc
ENTRYPOINT ["/omc"]
