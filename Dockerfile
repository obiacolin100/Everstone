# Multi-stage Dockerfile for STARK application

# Stage 1: Build shared package
FROM node:20-alpine AS shared-builder
WORKDIR /app
COPY package*.json ./
COPY tsconfig.base.json ./
COPY shared/ ./shared/
RUN npm install --legacy-peer-deps
RUN npm run build --workspace=shared

# Stage 2: Build client
FROM node:20-alpine AS client-builder
WORKDIR /app
COPY package*.json ./
COPY tsconfig.base.json ./
COPY shared/ ./shared/
COPY client/package*.json ./client/
RUN npm install --legacy-peer-deps
COPY client/ ./client/
RUN npm run build --workspace=client

# Stage 3: Build server
FROM node:20-alpine AS server-builder
WORKDIR /app
COPY package*.json ./
COPY tsconfig.base.json ./
COPY shared/ ./shared/
COPY server/package*.json ./server/
RUN npm install --legacy-peer-deps
COPY server/ ./server/
RUN npm run build --workspace=server

# Stage 4: Production server with client static files
FROM node:20-alpine AS production
WORKDIR /app

# Install dumb-init for proper signal handling
RUN apk add --no-cache dumb-init

# Copy package files and shared package
COPY package*.json ./
COPY tsconfig.base.json ./
COPY shared/ ./shared/
COPY server/package*.json ./server/

# Install dependencies
RUN npm install --legacy-peer-deps --omit=dev

# Copy built files
COPY --from=shared-builder /app/shared/dist ./shared/dist
COPY --from=server-builder /app/server/dist ./dist
COPY --from=client-builder /app/client/dist ./public

# Create logs directory
RUN mkdir -p logs

# Set environment variables
ENV NODE_ENV=production
ENV PORT=3003

# Expose port
EXPOSE 3003

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3003/api/v1/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

# Use dumb-init to handle signals properly
ENTRYPOINT ["dumb-init", "--"]

# Start server
CMD ["node", "dist/index.js"]
