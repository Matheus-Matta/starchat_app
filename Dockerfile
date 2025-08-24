# Imagem final: Ruby + Node + pnpm + deps de build
FROM ruby:3.4.4-slim AS base

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential curl git ca-certificates \
    libpq-dev pkg-config openssl \
    && rm -rf /var/lib/apt/lists/*

# Node 18 + corepack (pnpm)
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - \
 && apt-get install -y nodejs \
 && corepack enable \
 && corepack prepare pnpm@10.2.0 --activate

# Bundler
RUN gem install bundler --no-document

WORKDIR /app

# Cache layer: gems
COPY Gemfile Gemfile.lock ./
RUN bundle config set deployment 'true' \
 && bundle config set with 'production' \
 && bundle config set without 'development test' \
 && bundle install --jobs 4

# Cache layer: node
COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile

# App
COPY . .

# Build de assets (se houver Vite/Webpacker/Tailwind)
ENV RAILS_ENV=production NODE_ENV=production
RUN bundle exec rails assets:precompile || true

# Entrypoint
COPY docker/entrypoints/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 3000
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
