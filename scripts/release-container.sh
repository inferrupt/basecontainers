#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 || $# -gt 3 ]]; then
  echo "usage: $0 <container> <major|minor|patch> [--push]" >&2
  exit 1
fi

container="$1"
bump="$2"
push_mode="${3:-}"

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

if [[ "${push_mode}" == "--push" ]]; then
  current_branch="$(git -C "${repo_root}" branch --show-current)"
  if [[ "${current_branch}" != "main" ]]; then
    echo "error: --push is only supported from main" >&2
    exit 1
  fi
fi

version_arg_name="$(printf '%s' "${container}" | tr '[:lower:]-' '[:upper:]_')_VERSION"
current_version="$(sed -nE "s/^ARG ${version_arg_name}=([0-9]+\.[0-9]+\.[0-9]+)$/\1/p" "${dockerfile}")"

if [[ -z "${current_version}" ]]; then
  echo "error: could not find ${version_arg_name} in ${dockerfile}" >&2
  exit 1
fi

IFS='.' read -r major minor patch < <(printf '%s\n' "${current_version}")

case "${bump}" in
  major)
    new_version="$((major + 1)).0.0"
    ;;
  minor)
    new_version="${major}.$((minor + 1)).0"
    ;;
  patch)
    new_version="${major}.${minor}.$((patch + 1))"
    ;;
  *)
    echo "error: bump must be one of: major, minor, patch" >&2
    exit 1
    ;;
esac

tag="v${new_version}"

if git -C "${repo_root}" rev-parse --verify --quiet "${tag}" >/dev/null; then
  echo "error: tag ${tag} already exists" >&2
  exit 1
fi

sed -i '' -E "s/^ARG ${version_arg_name}=${current_version}$/ARG ${version_arg_name}=${new_version}/" "${dockerfile}"

git -C "${repo_root}" add "${container}"

if git -C "${repo_root}" diff --cached --quiet -- "${container}"; then
  echo "error: no staged changes found under ${container}" >&2
  exit 1
fi

git -C "${repo_root}" commit -m "chore(${container}): release ${tag}"
git -C "${repo_root}" tag "${tag}"

printf 'Released %s as %s\n' "${container}" "${tag}"

if [[ "${push_mode}" == "--push" ]]; then
  git -C "${repo_root}" push origin HEAD "refs/tags/${tag}"
  printf 'Pushed branch %s and tag %s to origin\n' "${current_branch}" "${tag}"
else
  printf 'Next: git push origin HEAD "refs/tags/%s"\n' "${tag}"
fi
