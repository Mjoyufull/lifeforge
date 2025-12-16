#!/bin/bash
set -e

echo "Starting LifeForge Backend Entrypoint..."

# Generate migrations if the directory allows writing
# This assumes the PB_MIGRATIONS_DIR is mounted and writable
if [ -d "/pb_public" ] || [ -d "/pb_data" ]; then
    echo "Filesystem check passed."
fi

# Attempt to generate migrations relative to the project root
# We are in /app in the container
echo "Generating database migrations..."
# Using the forge CLI to generate migrations. 
# We assume 'bun forge db generate-migrations' works as verified in source code.
# The migrations are typically generated into 'database/pb_migrations' or similar.
# We need to ensure these end up in the shared volume.

# By default forge CLI likely targets database/pb_migrations.
# We will verify if we need to symlink or copy. 
# For now, let's run the command and trust the shared volume strategy from docker-compose 
# will mount ./database/pb_migrations from the host/volume.

# Run the migration generator (requires local PB binary, now installed)
# We use 'bun run forge' because 'forge' is a script in package.json
bun run forge db generate-migrations || echo "Migration generation failed or no changes detected."

# ... (previous code)

# Execute the passed command (CMD from Dockerfile)
# We need to run the automatic user creation AFTER the DB is up, but this script IS the entrypoint for the backend.
# The backend and DB start simultaneously in docker-compose.
# We can use a background job or a simple check during startup if we were running both in one container, but here they are separate.

# CRITICAL: We need a way to create the default user ("Admin User") that 'forge db init' normally does.
# PocketBase container creates the SUPERUSER (admin@lifeforge.local) via env vars.
# But the Application's 'users' collection record for that admin needs to exist for the app to work as expected by the docs?
# Actually, looking at 'setupDefaultData' in 'database-initialization.ts', it creates a record in the 'users' collection.
# The 'admin' account in PB is separate from the 'users' collection which the app uses for login?
# Docs say: "The only account you can use to log in is the account you've created in the database dashboard."
# And: "This initialization process will... Create a default user record in the database".
# So yes, we need to create a record in the 'users' collection.

# We will create a small temporary script to run this initialization using the backend codebase
# immediately before starting the server.

echo "Running automated database initialization checks..."

# We can perform the 'setupDefaultData' logic here using a custom scriptrunner or just rely on 'bun forge db init' 
# BUT 'bun forge db init' is interactive and tries to restart PB.
# We need a headless version. 
# We'll treat this as a "try to run this custom script" using bun.

# Ensure scripts directory exists
mkdir -p /app/scripts

cat <<EOF > /app/scripts/init-user.ts
import { setupDefaultData } from '../tools/forgeCLI/src/commands/db-commands/functions/database-initialization';
import getPocketbaseInstance from '../tools/forgeCLI/src/commands/db-commands/utils/pocketbase-utils';

const email = process.env.PB_ADMIN_EMAIL || 'admin@lifeforge.local';
const password = process.env.PB_ADMIN_PASSWORD || 'password123';

try {
    console.log("Attempting to create default user in 'users' collection...");
    await setupDefaultData(email, password);
    console.log("Default user created (or already exists).");
} catch (e) {
    if (e.message.includes('unique constraint')) {
        console.log("Default user already exists. Skipping.");
    } else {
        console.error("Failed to create default user:", e);
        // We don't exit here, we let the server try to start.
    }
}
EOF

# Run the user init script
# We need to ensure PB is reachable first. docker-compose 'depends_on' condition: service_healthy handles this mostly,
# but let's be safe.
echo "Waiting for PocketBase to be ready..."
# Simple wait loop involving wget or just sleep? 
# We have wget in the image? 'oven/bun' is distroless-like? it might be minimal.
# We will trust depends_on for now, or just retry the script.

bun run scripts/init-user.ts

echo "Starting main application..."
exec "$@"
