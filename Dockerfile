FROM node:23-alpine AS node

FROM ruby:3.4.4-alpine3.21 AS pre-builder

ARG NODE_VERSION="23.7.0"
ARG PNPM_VERSION="10.2.0"
ENV NODE_VERSION=${NODE_VERSION}
ENV PNPM_VERSION=${PNPM_VERSION}

ARG BUNDLE_WITHOUT="development:test"
ENV BUNDLE_WITHOUT=${BUNDLE_WITHOUT}
ENV BUNDLER_VERSION=2.5.11

ARG RAILS_SERVE_STATIC_FILES=true
ENV RAILS_SERVE_STATIC_FILES=${RAILS_SERVE_STATIC_FILES}

ARG RAILS_ENV=production
ENV RAILS_ENV=${RAILS_ENV}

ARG NODE_OPTIONS="--max-old-space-size=4096 --openssl-legacy-provider"
ENV NODE_OPTIONS=${NODE_OPTIONS}

ENV BUNDLE_PATH="/gems"

RUN apk add --no-cache \
  openssl \
  tar \
  build-base \
  tzdata \
  postgresql-dev \
  postgresql-client \
  git \
  curl \
  xz \
  vips \
  libffi-dev \
  libffi \
  pkgconf

RUN gem install bundler:${BUNDLER_VERSION}

COPY --from=node /usr/local/bin/node /usr/local/bin/
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules

RUN ln -s /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
  && ln -s /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx \
  && npm install -g pnpm@${PNPM_VERSION}

ENV PNPM_HOME="/root/.local/share/pnpm"
ENV PATH="$PNPM_HOME:$PATH"

WORKDIR /app

COPY Gemfile Gemfile.lock ./

RUN bundle config set --local force_ruby_platform true \
  && if [ "$RAILS_ENV" = "production" ]; then \
       bundle config set without 'development test'; \
     fi \
  && bundle install -j 4 -r 3

COPY package.json pnpm-lock.yaml ./

RUN pnpm install --frozen-lockfile

COPY . /app

RUN mkdir -p /app/log

## --- BUILD DE FRONT (VITE) E ASSETS RAILS (produção) ---
RUN if [ "$RAILS_ENV" = "production" ]; then \
  export SECRET_KEY_BASE=precompile_placeholder RAILS_LOG_TO_STDOUT=enabled NODE_ENV=production; \
  bundle exec rake vite:build && \
  bundle exec rake assets:precompile; \
fi

# Limpeza (após o build, para manter o manifest e reduzir a imagem)
RUN rm -rf spec node_modules tmp/cache

RUN git rev-parse HEAD > /app/.git_sha || echo unknown > /app/.git_sha

RUN rm -rf /gems/ruby/3.4.0/cache/*.gem \
  && find /gems/ruby/3.4.0/gems/ \( -name "*.c" -o -name "*.o" \) -delete \
  && rm -rf .git \
  && rm -f .gitignore

FROM ruby:3.4.4-alpine3.21

ARG BUNDLE_WITHOUT="development:test"
ENV BUNDLE_WITHOUT=${BUNDLE_WITHOUT}
ENV BUNDLER_VERSION=2.5.11

ARG EXECJS_RUNTIME="Disabled"
ENV EXECJS_RUNTIME=${EXECJS_RUNTIME}

ARG RAILS_SERVE_STATIC_FILES=true
ENV RAILS_SERVE_STATIC_FILES=${RAILS_SERVE_STATIC_FILES}

ARG BUNDLE_FORCE_RUBY_PLATFORM=1
ENV BUNDLE_FORCE_RUBY_PLATFORM=${BUNDLE_FORCE_RUBY_PLATFORM}

ARG RAILS_ENV=production
ENV RAILS_ENV=${RAILS_ENV}

ENV BUNDLE_PATH="/gems"

RUN apk add --no-cache \
  openssl \
  tzdata \
  postgresql-client \
  imagemagick \
  vips \
  libffi

RUN gem install bundler:${BUNDLER_VERSION}

COPY --from=pre-builder /gems/ /gems/
COPY --from=pre-builder /app /app

WORKDIR /app

RUN chmod +x docker/entrypoints/rails.sh

EXPOSE 3000