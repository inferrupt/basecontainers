#!/bin/sh
set -eu

if [ "$(id -u)" = "0" ]; then
  mkdir -p \
    /home/agent/.local/bin \
    /home/agent/.cache \
    /home/agent/.config \
    /home/agent/.local/share \
    /home/agent/.local/state \
    /home/agent/.codex

  chown -R 504:20 /home/agent 2>/dev/null || true

  exec gosu agent "$@"
fi

exec "$@"
