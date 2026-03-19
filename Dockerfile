# DataLog Jekyll Theme - Production Image
# =========================================
# Multi-stage build: builds the site, then serves it with nginx.
#
# Usage:
#   docker build -t datalog .
#   docker run -p 8080:80 datalog
#
# Build args:
#   JEKYLL_ENV   - Jekyll environment (default: production)
#   BASEURL      - Site base URL (default: empty)

# ---------------------------------------------------------------------------
# Stage 1: Build the static site
# ---------------------------------------------------------------------------
FROM ruby:3.2-slim AS builder

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
    build-essential \
    git \
    curl \
    libvips \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 20 LTS
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y --no-install-recommends nodejs && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Install Ruby dependencies
COPY Gemfile Gemfile.lock datalog-theme.gemspec ./
COPY lib/datalog/theme/version.rb lib/datalog/theme/version.rb
RUN bundle config set --local without 'development' && \
    bundle install --jobs 4

# Install Node dependencies
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

# Install Python dependencies for Jupyter notebook support
RUN pip3 install --no-cache-dir --break-system-packages nbformat

# Copy source
COPY . .

# Build JS bundles
RUN npm run build:js

# Build the Jekyll site
ARG JEKYLL_ENV=production
ARG BASEURL=""
ENV JEKYLL_ENV=${JEKYLL_ENV}
RUN bundle exec jekyll build --trace \
    --baseurl "${BASEURL}" \
    --destination /build/_site

# ---------------------------------------------------------------------------
# Stage 2: Serve with nginx
# ---------------------------------------------------------------------------
FROM nginx:1.27-alpine AS runtime

# Remove default nginx content
RUN rm -rf /usr/share/nginx/html/*

# Copy built site
COPY --from=builder /build/_site /usr/share/nginx/html

# Custom nginx config for SPA-like routing and caching
RUN cat > /etc/nginx/conf.d/default.conf <<'NGINX'
server {
    listen 80;
    listen [::]:80;
    server_name _;

    root /usr/share/nginx/html;
    index index.html;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 256;
    gzip_types text/html text/css application/javascript application/json
               image/svg+xml application/xml text/plain;

    # Cache static assets (hashed filenames)
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff2?|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;
    }

    # HTML pages - short cache, always revalidate
    location ~* \.html$ {
        expires 10m;
        add_header Cache-Control "public, must-revalidate";
    }

    # Clean URLs - try file, then directory, then 404
    location / {
        try_files $uri $uri/ $uri.html =404;
    }

    # Custom 404
    error_page 404 /404.html;
    location = /404.html {
        internal;
    }
}
NGINX

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD wget -qO- http://localhost/ || exit 1

CMD ["nginx", "-g", "daemon off;"]
