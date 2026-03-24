#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <container>" >&2
  exit 1
fi

container="$1"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dockerfile="${repo_root}/${container}/Dockerfile"
compose_file="${repo_root}/${container}/compose.yaml"
justfile="${repo_root}/${container}/justfile"
workflow="${repo_root}/.github/workflows/build-containers.yml"

[[ -f "${dockerfile}" ]] || { echo "error: missing ${dockerfile}" >&2; exit 1; }
[[ -f "${compose_file}" ]] || { echo "error: missing ${compose_file}" >&2; exit 1; }
[[ -f "${justfile}" ]] || { echo "error: missing ${justfile}" >&2; exit 1; }
[[ -f "${workflow}" ]] || { echo "error: missing ${workflow}" >&2; exit 1; }

expected_image="ghcr.io/inferrupt/${container}"

grep -Eq '^ARG IMAGE_VERSION=[0-9]+\.[0-9]+\.[0-9]+$' "${dockerfile}" || {
  echo "error: ${dockerfile} must define ARG IMAGE_VERSION=<semver>" >&2
  exit 1
}

grep -Fq 'LABEL org.opencontainers.image.version="${IMAGE_VERSION}"' "${dockerfile}" || {
  echo "error: ${dockerfile} must label org.opencontainers.image.version from IMAGE_VERSION" >&2
  exit 1
}

grep -Fq "version_arg_pattern = re.compile(r'^ARG\\s+IMAGE_VERSION=([0-9]+\\.[0-9]+\\.[0-9]+)$')" "${workflow}" || {
  echo "error: workflow must parse IMAGE_VERSION exactly" >&2
  exit 1
}

grep -Fq 'type=raw,value=${{ matrix.container.version }},enable=${{ matrix.container.version != '\'''\'' }}' "${workflow}" || {
  echo "error: workflow must publish the container Dockerfile version as an image tag" >&2
  exit 1
}

grep -Fq "${expected_image}:latest" "${compose_file}" || {
  echo "error: ${compose_file} must default to ${expected_image}:latest" >&2
  exit 1
}

grep -Fq "${expected_image}" "${justfile}" || {
  echo "error: ${justfile} must default IMAGE_REPO to ${expected_image}" >&2
  exit 1
}

echo "metadata ok for ${container}"
