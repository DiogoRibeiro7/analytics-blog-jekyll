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
FROM ruby:3.4-slim AS builder

# libssl-dev and libyaml-dev: with no Gemfile.lock, Bundler resolves gems such
# as openssl and psych that compile against these headers, which the slim image
# does not ship.
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
    build-essential \
    git \
    curl \
    libssl-dev \
    libyaml-dev \
    libvips \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 22 LTS, the version CI builds the bundles with
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get install -y --no-install-recommends nodejs && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Install Ruby dependencies. The repository has no Gemfile.lock (copying one
# stopped the build here), and the Gemfile loads the gemspec, which requires
# version.rb and package.rb.
COPY Gemfile datalog-theme.gemspec ./
COPY lib/datalog/theme/version.rb lib/datalog/theme/package.rb lib/datalog/theme/
RUN bundle config set --local without 'development' && \
    bundle install --jobs 4

# Install Node dependencies, dev dependencies included: esbuild, which builds
# the bundles below, is one. None of it reaches the nginx image.
COPY package.json package-lock.json ./
RUN npm ci

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
FROM nginx:1.30-alpine AS runtime

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
