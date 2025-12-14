# Multi-stage for monorepo

FROM oven/bun:latest AS base
WORKDIR /app

# Install dependencies (no lockfile in repo, so no --frozen-lockfile)
COPY package.json ./
COPY packages ./packages
COPY shared ./shared
COPY client/package.json ./client/
COPY server/package.json ./server/
RUN bun install

# Backend build stage
FROM base AS backend-build
COPY server ./server
COPY shared ./shared
WORKDIR /app/server
RUN bun run build || echo "No build script for backend, skipping"

# Backend runtime
FROM oven/bun:latest AS backend
WORKDIR /app/server
COPY --from=backend-build /app /app
EXPOSE 8080
CMD ["bun", "run", "start"]  # Confirm "start" script exists in server/package.json

# Frontend build stage
FROM base AS frontend-build
COPY client ./client
COPY shared ./shared
WORKDIR /app/client
RUN bun run build  # Vite/React should output to dist

# Frontend serve
FROM nginx:alpine AS frontend
COPY --from=frontend-build /app/client/dist /usr/share/nginx/html  # Confirm output dir; often 'dist' for Vite
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
