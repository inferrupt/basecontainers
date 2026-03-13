# Multi-container entrypoint for the devcontainers repo.

# List available container environments.
default:
	just --list

# List the currently scaffolded container definitions.
containers:
	@printf '%s\n' chae1

# Run a `chae1` recipe from the repo root.
chae1 +args:
	@JUST_JUSTFILE={{justfile_directory() + "/chae1/justfile"}} just {{args}}

# Run the local devc CLI test suite.
devc-test:
	@/Users/w1/.local/share/cargo/bin/cargo test --manifest-path {{justfile_directory() + "/devc-cli/Cargo.toml"}}

# Install the local devc CLI from source.
devc-install:
	@/Users/w1/.local/share/cargo/bin/cargo install --path {{justfile_directory() + "/devc-cli"}}
