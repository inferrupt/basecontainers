#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "usage: $0 <container> [--push]" >&2
  exit 1
fi

container="$1"
push_mode="${2:-}"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dockerfile="${repo_root}/${container}/Dockerfile"

if [[ ! -f "${dockerfile}" ]]; then
  echo "error: unknown container '${container}'" >&2
  exit 1
fi

if [[ -n "${push_mode}" && "${push_mode}" != "--push" ]]; then
  echo "error: unsupported option '${push_mode}'" >&2
  exit 1
fi

current_branch="$(git -C "${repo_root}" branch --show-current)"
if [[ "${current_branch}" != "main" ]]; then
  echo "error: tagging is only supported from main" >&2
  exit 1
fi

current_version="$(sed -nE 's/^ARG IMAGE_VERSION=([0-9]+\.[0-9]+\.[0-9]+)$/\1/p' "${dockerfile}")"
if [[ -z "${current_version}" ]]; then
  echo "error: could not find IMAGE_VERSION in ${dockerfile}" >&2
  exit 1
fi

tag="${container}/v${current_version}"

if git -C "${repo_root}" rev-parse --verify --quiet "${tag}" >/dev/null; then
  echo "error: tag ${tag} already exists" >&2
  exit 1
fi

git -C "${repo_root}" tag "${tag}"
printf 'Tagged %s as %s\n' "${container}" "${tag}"

if [[ "${push_mode}" == "--push" ]]; then
  git -C "${repo_root}" push origin "refs/tags/${tag}"
  printf 'Pushed tag %s to origin\n' "${tag}"
else
  printf 'Next: git push origin "refs/tags/%s"\n' "${tag}"
fi
