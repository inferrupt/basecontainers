FROM debian:trixie-slim

ARG USERNAME=agent
ARG UID=504
ARG GID=20
ARG CHAE1_VERSION=0.1.0
ARG MISE_VERSION=2026.3.6

LABEL org.opencontainers.image.title="chae1"
LABEL org.opencontainers.image.description="Reusable development container image containing mise."
LABEL org.opencontainers.image.source="https://github.com/inferrupt/basecontainers"
LABEL org.opencontainers.image.licenses="Apache-2.0"
LABEL org.opencontainers.image.version="${CHAE1_VERSION}"

ENV DEBIAN_FRONTEND=noninteractive
ENV PATH="/usr/local/bin:${PATH}"

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    curl \
    git \
    gosu \
    openssh-client \
    build-essential \
    pkg-config \
    libssl-dev \
    file \
    unzip \
    zlib1g-dev \
    xz-utils \
    procps \
  && rm -rf /var/lib/apt/lists/*

RUN arch="$(dpkg --print-architecture)" \
  && case "${arch}" in \
       amd64) mise_arch="x64" ;; \
       arm64) mise_arch="arm64" ;; \
       *) echo "unsupported architecture: ${arch}" >&2; exit 1 ;; \
     esac \
  && curl -fsSL "https://github.com/jdx/mise/releases/download/v${MISE_VERSION}/mise-v${MISE_VERSION}-linux-${mise_arch}" -o /usr/local/bin/mise \
  && chmod 0755 /usr/local/bin/mise

RUN set -eux; \
    if ! getent group "${GID}" >/dev/null; then groupadd --gid "${GID}" staff; fi; \
    useradd \
      --uid "${UID}" \
      --gid "${GID}" \
      --create-home \
      --home-dir "/home/${USERNAME}" \
      --shell /bin/bash \
      "${USERNAME}"; \
    mkdir -p "/home/${USERNAME}/.local/bin" \
             "/home/${USERNAME}/.cache" \
             "/home/${USERNAME}/.config" \
             "/home/${USERNAME}/.local/share" \
             "/home/${USERNAME}/.local/state" \
             "/home/${USERNAME}/.codex"; \
    chown -R "${UID}:${GID}" "/home/${USERNAME}"

COPY --link --chown=${UID}:${GID} home/ /home/${USERNAME}/
COPY --link scripts/entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod 0755 /usr/local/bin/entrypoint.sh

WORKDIR /workspaces

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["sleep", "infinity"]
