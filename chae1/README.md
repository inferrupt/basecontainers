# chae1

`chae1` is a reusable development container image plus local compose/just wiring.
Its Docker build inputs and helper scripts live entirely within `containers/chae1/`.

Defaults:

- Workspace path: sibling checkout `../workspace_agent`
- Default working directory inside container: `/workspaces`
- Registry image: `ghcr.io/inferrupt/chae1:latest`
- Container version: `0.1.0`

Run from the repo root:

```bash
just chae1 --list
just chae1 pin-latest
just chae1 up
just chae1 shell
```

Override the mounted repo when needed:

```bash
AGENT_WORKSPACE=/absolute/path/to/other/repo WORKSPACE_NAME=my_repo just chae1 up
```

Versioning:

- `chae1` uses manual SemVer for container changes.
- Use `just release chae1 <major|minor|patch>` to bump `CHAE1_VERSION`, commit `chae1/`, and create a lightweight `chae1/v<version>` tag.
- Use `just release-push chae1 <major|minor|patch>` from `main` to do the release and push both `main` and the matching lightweight tag.
- The publish workflow tags GHCR images with the Dockerfile version, commit SHA, and `latest`.
