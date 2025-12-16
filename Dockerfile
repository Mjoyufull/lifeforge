# Base stage for building
FROM oven/bun:latest AS builder
WORKDIR /app

# Copy configuration files
# bun.lock is gitignored, so we don't copy it.
# We copy package.json and config files.
COPY package.json tsconfig.json tsconfig.eslint.json eslint.config.js ./

# Copy all workspaces
COPY apps/ ./apps/
COPY client/ ./client/
COPY database/ ./database/
COPY docs/ ./docs/
COPY env/ ./env/
COPY packages/ ./packages/
COPY scripts/ ./scripts/
COPY server/ ./server/
COPY shared/ ./shared/
COPY tools/ ./tools/

# Install dependencies with isolated linker
# Removing --frozen-lockfile because bun.lock is not in the repo
# causes issues in the docker container.
RUN bun install --linker isolated

# 1. Build Shared (Dependency)
WORKDIR /app/shared
RUN bun run build

# 2. Build Server Types (Required for UI)
WORKDIR /app/server
RUN bun run types

# 3. Build UI Library
WORKDIR /app/packages/lifeforge-ui
RUN bun run build

# 4. Build Server
WORKDIR /app/server
RUN bun run build

# 5. Build Client with /api proxy path
WORKDIR /app/client
ARG VITE_API_HOST=/api
ENV VITE_API_HOST=$VITE_API_HOST
# Avoid 'bun run types' because it iterates over ../apps/ which might be empty, causing failure.
RUN bun x tsc -b && bun run vite build

# --- Runtime Stage: Backend ---
FROM oven/bun:latest AS backend-runtime
WORKDIR /app

# Install system dependencies for pdf2pic and other tools
RUN apt-get update && apt-get install -y \
    ghostscript \
    graphicsmagick \
    wget \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Download PocketBase binary for CLI usage (migrations)
# Using version 0.34.2 (Latest Stable)
RUN mkdir -p /app/database
RUN wget https://github.com/pocketbase/pocketbase/releases/download/v0.34.2/pocketbase_0.34.2_linux_amd64.zip -O /tmp/pb.zip \
    && unzip /tmp/pb.zip -d /app/database/ \
    && chmod +x /app/database/pocketbase \
    && rm /tmp/pb.zip


# Copy necessary files for backend
COPY --from=builder /app/server/dist ./dist
# We need node_modules for runtime dependencies
# In a perfect world we'd prune dev deps, but with workspaces it's complex.
# Copying full node_modules is safest for now.
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./package.json
# Copy tools so we can run auto-init scripts that depend on forgeCLI code
COPY --from=builder /app/tools ./tools

# Environment Setup
ENV NODE_ENV=production
ENV PORT=8080
EXPOSE 8080

COPY scripts/docker-entrypoint.sh /app/docker-entrypoint.sh
RUN chmod +x /app/docker-entrypoint.sh

ENTRYPOINT ["/app/docker-entrypoint.sh"]
CMD ["bun", "dist/server.js"]

# --- Runtime Stage: Frontend ---
FROM nginx:alpine AS frontend-runtime
COPY --from=builder /app/client/dist /usr/share/nginx/html
COPY --from=builder /app/client/nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
