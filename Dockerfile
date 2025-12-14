FROM oven/bun:latest AS base
WORKDIR /app

# Copy everything first for better debugging
COPY . .

# Debug: List files to confirm structure
RUN ls -la && \
    echo "Root package.json exists?" && cat package.json || echo "No root package.json!" && \
    echo "Client package.json:" && cat client/package.json || echo "No client dir" && \
    echo "Server package.json:" && cat server/package.json || echo "No server dir"

# Install deps - separate for better error visibility
RUN bun install --verbose || (echo "bun install failed" && cat bun-debug.log && exit 1)

# Backend stage
FROM base AS backend-build
WORKDIR /app/server  # Adjust if server entry is different
RUN bun run build || echo "No backend build script - skipping (dev mode?)"

FROM oven/bun:latest AS backend
WORKDIR /app/server
COPY --from=backend-build /app /app
EXPOSE 8080
CMD ["bun", "run", "dev"]  # Change to "start" if prod script exists; many Bun apps use "dev" for hot reload

# Frontend stage
FROM base AS frontend-build
WORKDIR /app/client  # Adjust if client dir name differs
RUN bun run build

FROM nginx:alpine AS frontend
COPY --from=frontend-build /app/client/dist /usr/share/nginx/html  # Confirm output dir in vite.config or logs
EXPOSE 80
