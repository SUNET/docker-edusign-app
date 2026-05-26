FROM node:22-alpine

# App lives here; will be a mounted volume at runtime
WORKDIR /home/node/app

# Drop root privileges (the node image ships with a 'node' user)
USER node

# At startup: install deps if needed, then build once and keep watching for changes
CMD ["sh", "-c", "npm install && npx webpack --config webpack.config.js --watch"]
