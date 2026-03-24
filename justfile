set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

repo_root := justfile_directory()
release_script := repo_root + "/scripts/release-container.sh"
metadata_test_script := repo_root + "/scripts/test-release-metadata.sh"
release_flow_test_script := repo_root + "/scripts/test-release-flow.sh"

_container-guard container:
	@test -f "{{repo_root}}/{{container}}/Dockerfile" || (echo "error: unknown container '{{container}}'" >&2; exit 1)

# List available top-level container directories.
containers:
	@find "{{repo_root}}" -mindepth 2 -maxdepth 2 -name Dockerfile -exec dirname {} \; | xargs -n1 basename

# Print the local image tag for a container.
image container:
	@just _container-guard "{{container}}"
	@echo "local/basecontainers-{{container}}:dev"

# Build a container locally with a clearly local-only image tag.
build container:
	@just _container-guard "{{container}}"
	docker build --tag "local/basecontainers-{{container}}:dev" "{{repo_root}}/{{container}}"

# Rebuild a container locally without using the Docker cache.
rebuild container:
	@just _container-guard "{{container}}"
	docker build --no-cache --tag "local/basecontainers-{{container}}:dev" "{{repo_root}}/{{container}}"

# Smoke-test a container by starting it locally and running a minimal shell check.
smoke container:
	@just _container-guard "{{container}}"
	docker run --rm --pull never --entrypoint /bin/sh "local/basecontainers-{{container}}:dev" -lc 'id >/dev/null'

# Build and smoke-test a container.
test container:
	@just build "{{container}}"
	@just smoke "{{container}}"

# Verify critical versioning and image metadata expectations for a container.
verify-release container:
	@just _container-guard "{{container}}"
	"{{metadata_test_script}}" "{{container}}"

# Verify the release workflow bumps IMAGE_VERSION, commits, and tags correctly in a temporary repo copy.
test-release container:
	@just _container-guard "{{container}}"
	"{{release_flow_test_script}}" "{{container}}"

# Bump a container SemVer in its Dockerfile, commit the container directory, and create a lightweight <container>/vX.Y.Z tag.
release container bump:
	@just _container-guard "{{container}}"
	"{{release_script}}" "{{container}}" "{{bump}}"

# Run the release workflow and push the current main branch plus the matching lightweight tag.
release-push container bump:
	@just _container-guard "{{container}}"
	"{{release_script}}" "{{container}}" "{{bump}}" --push

default:
	@just --list
