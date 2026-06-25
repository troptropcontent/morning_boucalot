FROM mcr.microsoft.com/devcontainers/ruby:4.0

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends libvips-dev && \
    rm -rf /var/lib/apt/lists/*

# Install Node.js LTS
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - && \
    apt-get install -y --no-install-recommends nodejs && \
    rm -rf /var/lib/apt/lists/*

# Install kamal for deployments
RUN gem install kamal && chmod -R g+w /usr/local/rvm/gems/default

# Pre-create .claude dir so the devcontainer volume mount initializes with correct ownership
RUN mkdir -p /home/vscode/.claude && chown -R vscode:vscode /home/vscode/.claude
