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
