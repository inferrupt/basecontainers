# basecontainers

Reusable development container definitions and local helper wiring.

Each top-level subdirectory that contains a `Dockerfile` is treated as a buildable container image. Container-specific build inputs, scripts, and local compose or `just` helpers live inside that container's directory.

Current containers:

- `chae1`

## Repository layout

- `./<container>/Dockerfile`: image definition for a container
- `./<container>/home/`: home-directory content copied into the image
- `./<container>/scripts/`: container-specific helper scripts
- `.github/workflows/build-containers.yml`: builds changed containers on pushes to `main` and publishes them to GHCR

## Publishing

GitHub Actions builds only the top-level container directories changed in a push to `main`.

Published images are pushed to:

- `ghcr.io/<repo-owner>/<container-name>`

Tags:

- SemVer tag from the container Dockerfile version, for example `0.1.0`
- full commit SHA for immutable pinning
- `latest` as a convenience pointer only

`latest` is intended for discovery, not for pinned use in `Dockerfile`, Compose, or other configuration. Prefer pinning to an immutable commit SHA tag.

## Local use

Use the root `justfile` to build and smoke-test a container locally before merging:

```bash
just containers
just build chae1
just test chae1
```

Local images are tagged as:

- `local/basecontainers-<container>:dev`

That makes locally built images easy to distinguish from GHCR-published images in `docker ps` or `docker compose ps`.

Container-specific runtime usage is documented in each container directory, for example:

- `./chae1/README.md`

## Releasing

For containers that use an `IMAGE_VERSION=x.y.z` Dockerfile argument, use:

```bash
just release <container> <major|minor|patch>
```

This will:

- bump the Dockerfile SemVer
- commit the container directory
- create a lightweight `<container>/v<version>` tag at that commit

To push both the current `main` branch and the matching lightweight tag:

```bash
just release-push <container> <major|minor|patch>
```
