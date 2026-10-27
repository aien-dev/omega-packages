#!/bin/sh
# sbom.sh TREE OMC -- print a minimal SPDX 2.3 JSON SBOM for omc on stdout.
# TREE is the unpacked omega-mv-<commit> source that omc was born from (scripts/omc-from-seed.sh).
# omc is a static ELF with no runtime dependencies, so the SBOM lists only what it is built from:
# the pinned source archive and every seed input named in TREE/seed/challenge/expected.txt, each with
# the sha256 measured from TREE. Exit 1 when a measured input disagrees with expected.txt.
set -eu
here=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
. "$here/pins.env"
[ $# -eq 2 ] || { echo "usage: sbom.sh TREE OMC" >&2; exit 2; }
tree=$1 omc=$2
exp=$tree/seed/challenge/expected.txt
[ -r "$exp" ] || { echo "FAIL no $exp" >&2; exit 1; }
osha=$(sha256sum "$omc" | cut -d' ' -f1)
[ "$osha" = "$OMC_SHA256" ] || { echo "FAIL omc sha256 $osha, pinned $OMC_SHA256" >&2; exit 1; }
created=$(date -u -d "@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y-%m-%dT%H:%M:%SZ)

files= rels= n=0
while read -r kind path sha bytes; do
  [ "$kind" = input ] || continue
  got=$(sha256sum "$tree/$path" | cut -d' ' -f1)
  [ "$got" = "$sha" ] || { echo "FAIL $path sha256 $got, expected.txt $sha" >&2; exit 1; }
  n=$((n + 1))
  id=SPDXRef-File-seed-$n
  files="$files${files:+,}
    {\"SPDXID\": \"$id\", \"fileName\": \"./$path\", \"checksums\": [{\"algorithm\": \"SHA256\", \"checksumValue\": \"$got\"}], \"licenseConcluded\": \"Apache-2.0\", \"copyrightText\": \"NOASSERTION\", \"comment\": \"$bytes bytes; seed-chain input\"}"
  rels="$rels,
    {\"spdxElementId\": \"SPDXRef-Package-omega-mv\", \"relationshipType\": \"CONTAINS\", \"relatedSpdxElement\": \"$id\"}"
done < "$exp"
[ "$n" -gt 0 ] || { echo "FAIL no input rows in $exp" >&2; exit 1; }

cat <<EOF
{
  "spdxVersion": "SPDX-2.3",
  "dataLicense": "CC0-1.0",
  "SPDXID": "SPDXRef-DOCUMENT",
  "name": "omc-$OMC_VERSION",
  "documentNamespace": "https://github.com/aien-dev/omega-packages/spdx/omc-$OMC_VERSION-$osha",
  "creationInfo": {"created": "$created", "creators": ["Organization: aien-dev", "Tool: omega-packages scripts/sbom.sh"]},
  "documentDescribes": ["SPDXRef-Package-omc"],
  "packages": [
    {"SPDXID": "SPDXRef-Package-omc", "name": "omc", "versionInfo": "$OMC_VERSION",
     "supplier": "Organization: aien-dev", "downloadLocation": "https://github.com/aien-dev/omega-packages/releases",
     "filesAnalyzed": false, "primaryPackagePurpose": "APPLICATION",
     "checksums": [{"algorithm": "SHA256", "checksumValue": "$osha"}],
     "licenseConcluded": "Apache-2.0", "licenseDeclared": "Apache-2.0", "copyrightText": "NOASSERTION",
     "comment": "Static AArch64 Linux ELF, no runtime dependencies. Built by seed/omega-from-seed.sh: seed0 (408 bytes) -> hex1 -> asm2 -> om4 -> omc -> omc -> omc."},
    {"SPDXID": "SPDXRef-Package-omega-mv", "name": "omega-mv", "versionInfo": "$OMEGA_MV_COMMIT",
     "supplier": "Organization: aien-dev",
     "downloadLocation": "https://github.com/aien-dev/omega-mv/archive/$OMEGA_MV_COMMIT.tar.gz",
     "filesAnalyzed": false,
     "checksums": [{"algorithm": "SHA256", "checksumValue": "$OMEGA_MV_TARBALL_SHA256"}],
     "licenseConcluded": "Apache-2.0", "licenseDeclared": "Apache-2.0", "copyrightText": "NOASSERTION",
     "comment": "Source archive. The files listed below are its seed-chain inputs, measured from the unpacked archive and checked against seed/challenge/expected.txt."}
  ],
  "files": [$files
  ],
  "relationships": [
    {"spdxElementId": "SPDXRef-DOCUMENT", "relationshipType": "DESCRIBES", "relatedSpdxElement": "SPDXRef-Package-omc"},
    {"spdxElementId": "SPDXRef-Package-omc", "relationshipType": "GENERATED_FROM", "relatedSpdxElement": "SPDXRef-Package-omega-mv"}$rels
  ]
}
EOF
