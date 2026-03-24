#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <base-ref> <head-ref>" >&2
  exit 1
fi

base_ref="$1"
head_ref="$2"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

changed_containers=()
while IFS= read -r dirname; do
  changed_containers+=("${dirname}")
done < <(
  git -C "${repo_root}" diff --name-only "${base_ref}" "${head_ref}" \
    | awk -F/ 'NF > 1 {print $1}' \
    | sort -u \
    | while read -r dirname; do
        [[ -n "${dirname}" && -f "${repo_root}/${dirname}/Dockerfile" ]] && printf '%s\n' "${dirname}"
      done
)

if [[ ${#changed_containers[@]} -eq 0 ]]; then
  echo "no changed container directories"
  exit 0
fi

failures=0

extract_version() {
  local ref="$1"
  local container="$2"
  git -C "${repo_root}" show "${ref}:${container}/Dockerfile" 2>/dev/null \
    | sed -nE 's/^ARG IMAGE_VERSION=([0-9]+\.[0-9]+\.[0-9]+)$/\1/p'
}

for container in "${changed_containers[@]}"; do
  base_version="$(extract_version "${base_ref}" "${container}")"
  head_version="$(extract_version "${head_ref}" "${container}")"

  if [[ -z "${head_version}" ]]; then
    echo "error: ${container}/Dockerfile at ${head_ref} must define ARG IMAGE_VERSION=<semver>" >&2
    failures=1
    continue
  fi

  if [[ "${base_version}" == "${head_version}" ]]; then
    echo "error: ${container} changed between ${base_ref} and ${head_ref} but IMAGE_VERSION stayed at ${head_version}" >&2
    failures=1
    continue
  fi

  echo "${container}: IMAGE_VERSION ${base_version:-<new>} -> ${head_version}"
done

exit "${failures}"
