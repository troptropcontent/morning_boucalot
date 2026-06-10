#!/bin/bash
set -e

sudo apt-get update -qq && sudo apt-get install -y libvips-dev

# Install Claude Code CLI
curl -fsSL https://claude.ai/install.sh | bash

# Set up project npm dependencies (DaisyUI for Tailwind)
npm init -y
npm install daisyui
