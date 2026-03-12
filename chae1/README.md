# chae1

`chae1` is a reusable development container image plus local compose/just wiring.

Defaults:

- Workspace path: `../../chora_platform_agent`
- Workspace name inside container: `chora_platform`
- Registry image: `ghcr.io/geoff-hill/chae1-devcontainer:latest`

Run from the repo root:

```bash
just chae1 --list
just chae1 pin-latest
just chae1 up
just chae1 shell
```

Override the mounted repo when needed:

```bash
WORKSPACE_PATH=/absolute/path/to/other/repo WORKSPACE_NAME=my_repo just chae1 up
```
