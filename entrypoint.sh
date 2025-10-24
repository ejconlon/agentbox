#!/bin/bash
# AgentBox entrypoint script - minimal initialization

set -e

# Ensure proper PATH
export PATH="$HOME/.local/bin:$PATH"

# Source NVM if available
if [ -s "$HOME/.nvm/nvm.sh" ]; then
    export NVM_DIR="$HOME/.nvm"
    source "$NVM_DIR/nvm.sh"
fi

# Create Python virtual environment if it doesn't exist in the project
if [ ! -d "${VIRTUAL_ENV}" ] && [ -f "/workspace/requirements.txt" -o -f "/workspace/pyproject.toml" -o -f "/workspace/setup.py" ]; then
    echo "🐍 Python project detected, creating virtual environment..."
    cd /workspace
    mkdir -p $(dirname ${VIRTUAL_ENV})
    uv sync --all-packages
    echo "✅ Virtual environment created at ${VIRTUAL_ENV}"
fi

# Set terminal for better experience
export TERM=xterm-256color

# Handle terminal size
if [ -t 0 ]; then
    # Update terminal size
    eval $(resize 2>/dev/null || true)
fi

# If running interactively, show welcome message
if [ -t 0 ] && [ -t 1 ]; then
    echo "🤖 AgentBox Development Environment"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📁 Workspace: /workspace"
    echo "🐍 Python: $(python3 --version 2>&1 | cut -d' ' -f2)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
fi

# Execute the command passed to docker run
exec "$@"
