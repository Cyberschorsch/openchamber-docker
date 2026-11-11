FROM node:24-bookworm-slim

ARG OPENCHAMBER_VERSION=latest
ARG OPENCODE_VERSION=latest

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      git openssh-client ca-certificates curl procps gosu ripgrep \
      python3 make g++ \
 && rm -rf /var/lib/apt/lists/*

RUN npm install -g "@openchamber/web@${OPENCHAMBER_VERSION}" "@opencode/cli@${OPENCODE_VERSION}" \
 && npm cache clean --force

RUN useradd -m -d /home/agent -s /bin/bash agent \
 && mkdir -p /home/agent/.config/opencode /home/agent/.config/openchamber \
             /home/agent/.local/share/opencode /home/agent/workspaces \
 && chown -R agent:agent /home/agent

ENV HOME=/home/agent \
    OPENCHAMBER_HOST=0.0.0.0 \
    PUID=1000 \
    PGID=1000

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /home/agent/workspaces
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s \
  CMD curl -fs http://localhost:3000/health || exit 1

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["openchamber", "serve", "--foreground", "--host", "0.0.0.0", "--port", "3000"]
