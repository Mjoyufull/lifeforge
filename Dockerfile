# Base stage for building
FROM oven/bun:latest AS builder
WORKDIR /app

# Copy configuration files
COPY package.json bun.lock tsconfig.json tsconfig.eslint.json eslint.config.js ./

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

# Install dependencies with isolated linker as recommended in docs
RUN bun install --frozen-lockfile --linker isolated

# 1. Build Shared (Dependency for everyone)
WORKDIR /app/shared
RUN bun run build

# 2. Build LifeForge UI (Depends on Server Types)
# We need to generate server types first because UI depends on them (?)
WORKDIR /app/server
RUN bun run types

WORKDIR /app/packages/lifeforge-ui
RUN bun run build

# 3. Build Server
WORKDIR /app/server
RUN bun run build

# 4. Build Client
WORKDIR /app/client
# Run vite build directly since we already manually built dependencies above
RUN bun run types && bun x vite build

# --- Runtime Stage: Backend ---
FROM oven/bun:latest AS backend-runtime
WORKDIR /app

# Copy necessary files for backend
COPY --from=builder /app/server/dist ./dist
# We need node_modules for runtime dependencies
# In a perfect world we'd prune dev deps, but with workspaces it's complex.
# Copying full node_modules is safest for now.
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./package.json

# Environment Setup
ENV NODE_ENV=production
ENV PORT=8080
EXPOSE 8080

CMD ["bun", "dist/server.js"]

# --- Runtime Stage: Frontend ---
FROM nginx:alpine AS frontend-runtime
COPY --from=builder /app/client/dist /usr/share/nginx/html
COPY --from=builder /app/client/nginx.conf /etc/nginx/conf.d/default.conf 2>/dev/null || :

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
