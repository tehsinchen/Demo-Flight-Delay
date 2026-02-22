# --- Build stage ---
FROM node:25-alpine AS build
WORKDIR /app

# Install deps (uses package-lock.json for reproducibility)
COPY package.json ./
RUN npm install --no-package-lock

# Copy the rest of the source
COPY . .

ENV VITE_API_BASE_URL="/api"
ENV VITE_APP_TITLE="Flight Operations Analytics"

RUN npm run build

# --- Runtime stage ---
FROM nginxinc/nginx-unprivileged:stable-alpine

# Use the default 'nginx' user provided by the image for workers (set in nginx.conf)
# Keep master as root so it can bind to :80.
COPY config/nginx.conf /etc/nginx/conf.d/default.conf

# Static files
COPY --from=build /app/dist /usr/share/nginx/html

EXPOSE 8080
CMD ["nginx", "-g", "daemon off;"]
