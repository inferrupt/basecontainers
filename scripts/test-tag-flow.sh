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

rm -rf .git
git init -q
git config user.name test
git config user.email test@example.com
git add .
git commit -q -m base
git branch -M main

output="$(bash ./scripts/tag-container.sh "${container}")"
current_version="$(sed -nE 's/^ARG IMAGE_VERSION=([0-9]+\.[0-9]+\.[0-9]+)$/\1/p' "${container}/Dockerfile")"
expected_tag="${container}/v${current_version}"

printf '%s\n' "${output}" | grep -Fq "Tagged ${container} as ${expected_tag}" || {
  echo "error: tag output did not report ${expected_tag}" >&2
  exit 1
}

test "$(git tag --points-at HEAD)" = "${expected_tag}" || {
  echo "error: HEAD tag was not ${expected_tag}" >&2
  exit 1
}

echo "tag flow ok for ${container}"
