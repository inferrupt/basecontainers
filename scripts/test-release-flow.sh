#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <container>" >&2
  exit 1
fi

container="$1"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

cp -R "${repo_root}" "${tmpdir}/basecontainers"
cd "${tmpdir}/basecontainers"

git checkout --quiet -b test-release
just release "${container}" patch >/tmp/test-release-flow.out

expected_tag="${container}/v0.1.1"

grep -Fq "Released ${container} as ${expected_tag}" /tmp/test-release-flow.out || {
  echo "error: release output did not report ${expected_tag}" >&2
  exit 1
}

test "$(git tag --points-at HEAD)" = "${expected_tag}" || {
  echo "error: HEAD tag was not ${expected_tag}" >&2
  exit 1
}

grep -Eq '^ARG IMAGE_VERSION=0\.1\.1$' "${container}/Dockerfile" || {
  echo "error: ${container}/Dockerfile was not bumped to IMAGE_VERSION=0.1.1" >&2
  exit 1
}

test "$(git log --format=%s -1)" = "chore(${container}): release ${expected_tag}" || {
  echo "error: release commit message was not correct" >&2
  exit 1
}

echo "release flow ok for ${container}"
