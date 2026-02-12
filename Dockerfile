# Stage 1: Build the application
FROM node:20-alpine AS builder

WORKDIR /app

# Copy package.json and package-lock.json first to leverage Docker cache
COPY package.json package-lock.json ./

# Install dependencies
# Using ci (clean install) for reproducible builds
RUN npm ci

# Copy the rest of the application code
COPY . .

# Build the SvelteKit application
RUN npm run build
# Prune development dependencies to keep the image small
# skipped npm prune to keep vite for preview

# Stage 2: Run the application
FROM node:20-alpine AS runner

WORKDIR /app

# Copy necessary files from the builder stage
COPY --from=builder /app/.svelte-kit ./.svelte-kit
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/svelte.config.js ./svelte.config.js
COPY --from=builder /app/vite.config.ts ./vite.config.ts
COPY --from=builder /app/static ./static

# Expose the port Vite preview runs on (default 4173, but we can verify)
EXPOSE 4173

# Start the application using vite preview
# --host 0.0.0.0 is crucial for Docker networking to work
CMD ["npm", "run", "preview", "--", "--host", "0.0.0.0"]
