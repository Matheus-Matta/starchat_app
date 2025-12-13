FROM node:23-alpine AS node

FROM ruby:3.4.4-alpine3.21 AS builder

ARG PNPM_VERSION=10.2.0
ARG BUNDLER_VERSION=2.5.11
ARG RAILS_ENV=production
ARG BUNDLE_WITHOUT="development:test"

ENV RAILS_ENV=${RAILS_ENV}
ENV NODE_ENV=production
ENV BUNDLE_WITHOUT=${BUNDLE_WITHOUT}
ENV BUNDLE_PATH=/gems
ENV RAILS_SERVE_STATIC_FILES=true
ENV NODE_OPTIONS="--max-old-space-size=4096 --openssl-legacy-provider"

RUN apk add --no-cache \
  build-base \
  git \
  tzdata \
  curl \
  xz \
  tar \
  openssl \
  postgresql-dev \
  postgresql-client \
  vips \
  imagemagick \
  libffi \
  libffi-dev \
  pkgconf

RUN gem install bundler:${BUNDLER_VERSION}

COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules

RUN ln -sf /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
  && ln -sf /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx \
  && npm install -g pnpm@${PNPM_VERSION}

WORKDIR /app

COPY Gemfile Gemfile.lock ./

RUN bundle config set --local force_ruby_platform true \
  && bundle config set --local path "${BUNDLE_PATH}" \
  && if [ "$RAILS_ENV" = "production" ]; then bundle config set without "development test"; fi \
  && bundle install -j 4 -r 3

COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile

COPY . .

RUN mkdir -p /app/log

RUN SECRET_KEY_BASE=precompile_placeholder RAILS_LOG_TO_STDOUT=enabled bundle exec rails assets:precompile

RUN git rev-parse HEAD > /app/.git_sha || echo unknown > /app/.git_sha

RUN rm -rf node_modules tmp/cache spec .git .gitignore \
  && rm -rf /gems/ruby/*/cache/*.gem \
  && find /gems -type f \( -name "*.c" -o -name "*.o" \) -delete

FROM ruby:3.4.4-alpine3.21

ARG BUNDLER_VERSION=2.5.11
ARG RAILS_ENV=production
ARG BUNDLE_WITHOUT="development:test"

ENV RAILS_ENV=${RAILS_ENV}
ENV BUNDLE_WITHOUT=${BUNDLE_WITHOUT}
ENV BUNDLE_PATH=/gems
ENV EXECJS_RUNTIME=Disabled
ENV RAILS_SERVE_STATIC_FILES=true
ENV BUNDLE_FORCE_RUBY_PLATFORM=1

RUN apk add --no-cache \
  tzdata \
  openssl \
  postgresql-client \
  vips \
  imagemagick \
  libffi \
  && gem install bundler:${BUNDLER_VERSION}

WORKDIR /app

COPY --from=builder /gems /gems
COPY --from=builder /app /app

RUN chmod +x docker/entrypoints/rails.sh

EXPOSE 3000