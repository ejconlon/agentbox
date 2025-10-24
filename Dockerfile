# AgentBox - Simplified multi-language development environment for Claude/Codex
FROM rockylinux:9.3

# Install system dependencies, Node.js LTS, GitHub CLI, and set locale
RUN --mount=type=cache,target=/var/cache/dnf \
    --mount=type=cache,target=/var/lib/dnf \
    dnf -y update && \
    dnf -y install epel-release && \
    \
    # Core utilities and build dependencies
    dnf -y install --allowerasing \
        # Essential tools
        ca-certificates curl wget gnupg2 sudo which \
        # Development tools
        git vim nano tmux htop tree \
        # Build tools
        make gcc gcc-c++ cmake pkg-config \
        # Shell and locale utilities
        bash-completion glibc-langpack-en glibc-locale-source \
        # Network tools
        openssh-clients nmap-ncat socat bind-utils iputils \
        # Archive tools
        zip unzip tar gzip bzip2 xz \
        # JSON/YAML processors
        jq yq \
        # Process management
        procps-ng psmisc \
        # Python toolchain
        python3.13 python3.13-pip python3.13-devel \
        # Cryptography headers
        openssl-devel libffi-devel \
        # Search tools
        ripgrep fd-find \
        # System metadata utilities
        shadow-utils findutils && \
    \
    # Enable Node.js LTS stream (e.g. nodejs:20) and install Node.js + npm
    dnf module enable -y nodejs:20 && \
    dnf -y install nodejs && \
    \
    # Install GitHub CLI (official repo for RHEL/Rocky/Fedora)
    dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo && \
    dnf -y install gh && \
    \
    # Clean up dnf metadata to keep the image lean
    dnf clean all

# Install 'just' from upstream release tarball
RUN set -eux; \
    ver="1.43.0"; \
    arch="$(uname -m)"; \
    url="https://github.com/casey/just/releases/download/${ver}/just-${ver}-${arch}-unknown-linux-musl.tar.gz"; \
    curl -L "$url" -o /tmp/just.tar.gz; \
    tar -xzf /tmp/just.tar.gz -C /tmp; \
    # the tarball contains a single 'just' binary
    install -m 0755 /tmp/just /usr/local/bin/just; \
    rm -f /tmp/just /tmp/just.tar.gz; \
    just --version

# Install Claude and Codex globally using system Node.js
RUN npm install -g @openai/codex @anthropic-ai/claude-code && \
    mkdir -p .claude .codex && \
    claude --version && codex --version

# Generate and ensure en_US.UTF-8 locale
RUN localedef -i en_US -f UTF-8 en_US.UTF-8 && \
    echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Set user vars
ARG USER_ID=1000 \
    GROUP_ID=1000 \
    USERNAME=agentbox

# Create non-root user (bash shell)
RUN groupadd -g ${GROUP_ID} ${USERNAME} || true && \
    useradd -m -u ${USER_ID} -g ${GROUP_ID} -s /bin/bash ${USERNAME} && \
    mkdir -p /etc/sudoers.d && \
    echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} && \
    chmod 0440 /etc/sudoers.d/${USERNAME}

# Switch to non-root user for home setup
USER ${USERNAME}

# Work in home directory
WORKDIR /home/${USERNAME}

# Create workspace directory, add local bin to path, and
# add terminal resize logic to bash for better interactive behavior
RUN mkdir -p .local/bin && \
    rm .bashrc && touch .bashrc && \
    echo 'export LANG=en_US.UTF-8' >> .bashrc && \
    echo 'export LANGUAGE=en_US:en' >> .bashrc && \
    echo "export PATH=\"/home/${USERNAME}/.local/bin:\${PATH}\"" >> .bashrc && \
    echo 'alias python=/usr/bin/python3.13' >> .bashrc && \
    echo 'alias python3=/usr/bin/python3.13' >> .bashrc && \
    echo 'alias pip=/usr/bin/pip3.13' >> .bashrc && \
    cat >> .bashrc <<'EOF'

if [[ -n "$PS1" ]] && command -v stty >/dev/null; then
  _update_size() {
    local rows cols
    { stty size; } 2>/dev/null | read rows cols
    ((rows)) && export LINES=$rows COLUMNS=$cols
  }
  trap _update_size WINCH
  _update_size
fi
EOF

# Install pipx (user scope) and then uv via pipx
RUN /usr/bin/python3.13 -m pip install --user --upgrade pip pipx && \
    .local/bin/pipx install uv

# Switch back to root for entrypoint setup
USER root
COPY entrypoint /usr/local/bin/entrypoint
RUN chmod +x /usr/local/bin/entrypoint
USER ${USERNAME}

# Default workdir to workspace
WORKDIR /workspace

ENTRYPOINT ["/usr/local/bin/entrypoint"]
CMD ["/bin/bash"]

