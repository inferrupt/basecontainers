# chae1

`chae1` is a reusable development container image plus local compose/just wiring.
Its Docker build inputs and helper scripts live entirely within `containers/chae1/`.

Defaults:

- Workspace path: sibling checkout `../workspace_agent`
- Default working directory inside container: `/workspaces`
- Registry image: `ghcr.io/geoff-hill/chae1-devcontainer:latest`
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
- Update `CHAE1_VERSION` in `chae1/Dockerfile` when this container changes.
- Tag the repository with `v<version>` for the corresponding commit.
