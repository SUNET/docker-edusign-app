FROM node:22-alpine

# App lives here; will be a mounted volume at runtime
WORKDIR /home/node/app

# At startup: install deps if needed, then build once and keep watching for changes
CMD ["sh", "build.sh"]
