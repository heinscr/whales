FROM node:18-alpine

WORKDIR /app

# Install dependencies
COPY package*.json ./
RUN npm ci --only=production

# Copy application and public files
COPY server.js .
COPY public ./public

# Set environment
ENV PORT=3000
ENV NODE_ENV=production

# Run application
CMD ["node", "server.js"]
