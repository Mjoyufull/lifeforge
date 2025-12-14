FROM oven/bun:latest AS base
WORKDIR /app
COPY package.json bun.lockb ./
COPY packages ./packages
COPY shared ./shared
COPY client/package.json ./client/
COPY server/package.json ./server/
RUN bun install --frozen-lockfile

FROM base AS backend-build
COPY server ./server
COPY shared ./shared
WORKDIR /app/server
RUN bun run build || echo "No build script, skipping"  # Fallback if no build

FROM oven/bun:latest AS backend
WORKDIR /app/server
COPY --from=backend-build /app /app
EXPOSE 8080
CMD ["bun", "run", "start"]  # Check server/package.json for exact script

FROM base AS frontend-build
COPY client ./client
COPY shared ./shared
WORKDIR /app/client
RUN bun run build

FROM nginx:alpine AS frontend
COPY --from=frontend-build /app/client/dist /usr/share/nginx/html  # Adjust if build output is different (e.g., /build)
EXPOSE 80
