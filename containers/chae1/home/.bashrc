# XDG base directories for interactive shells.
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

# Tool state should live under the XDG tree.
export MISE_DATA_DIR="${MISE_DATA_DIR:-$XDG_DATA_HOME/mise}"
export MISE_CACHE_DIR="${MISE_CACHE_DIR:-$XDG_CACHE_HOME/mise}"

# Prefer immutable image-installed tools, then user-local tools.
case ":$PATH:" in
  *":/usr/local/bin:"*) ;;
  *) PATH="/usr/local/bin:$PATH" ;;
esac
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) PATH="$HOME/.local/bin:$PATH" ;;
esac
export PATH

# Activate mise for interactive shell shims and env resolution.
eval "$(mise activate bash)"
