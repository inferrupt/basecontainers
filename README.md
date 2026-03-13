# devcontainers

Reusable development container images and local compose/just wiring.

Current containers:

- `chae1`

Run container-specific commands from the repo root with:

```bash
just chae1 --list
```

Install the local CLI with:

```bash
/Users/w1/.local/share/cargo/bin/cargo install --path devc-cli
```

Container definitions live under `containers/<name>/` and each container directory
is self-contained for Docker build inputs and helper scripts.
