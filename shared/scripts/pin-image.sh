#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "usage: $0 <env-var-name> <image-repo> <output-file>" >&2
  exit 1
fi

env_var_name="$1"
image_repo="$2"
output_file="$3"

manifest_json="$(docker buildx imagetools inspect "${image_repo}:latest" --format '{{json .Manifest}}')"
digest="$(printf '%s' "$manifest_json" | tr -d '\n' | grep -o '"digest":[[:space:]]*"[^"]*"' | head -n1 | sed 's/.*"digest":[[:space:]]*"\([^"]*\)"/\1/')"

if [ -z "$digest" ]; then
  echo "error: could not resolve digest for ${image_repo}:latest" >&2
  exit 1
fi

printf '%s=%s@%s\n' "$env_var_name" "$image_repo" "$digest" > "$output_file"
printf 'wrote %s=%s@%s to %s\n' "$env_var_name" "$image_repo" "$digest" "$output_file"
