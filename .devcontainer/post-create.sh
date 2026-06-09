#!/bin/bash
set -e

# Install Claude Code CLI
curl -fsSL https://claude.ai/install.sh | bash

# Set up project npm dependencies (DaisyUI for Tailwind)
npm init -y
npm install daisyui
