FROM mcr.microsoft.com/devcontainers/ruby:4.0

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends libvips-dev && \
    rm -rf /var/lib/apt/lists/*

# Install Node.js LTS
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - && \
    apt-get install -y --no-install-recommends nodejs && \
    rm -rf /var/lib/apt/lists/*

# Install the 1Password CLI (op) from 1Password's signed apt repository;
# bin/dev uses it to load secrets from .env.1password
RUN curl -fsSL https://downloads.1password.com/linux/keys/1password.asc | \
      gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/$(dpkg --print-architecture) stable main" \
      > /etc/apt/sources.list.d/1password.list && \
    apt-get update -qq && \
    apt-get install -y --no-install-recommends 1password-cli && \
    rm -rf /var/lib/apt/lists/*

# Install kamal for deployments
RUN gem install kamal && chmod -R g+w /usr/local/rvm/gems/default

# Pre-create .claude dir so the devcontainer volume mount initializes with correct ownership
RUN mkdir -p /home/vscode/.claude && chown -R vscode:vscode /home/vscode/.claude
