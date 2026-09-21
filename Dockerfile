FROM ruby:4.0.6-alpine3.24 AS build

RUN apk add --no-cache --virtual .build-deps build-base

WORKDIR /app

COPY Gemfile Gemfile.lock ./

ENV BUNDLE_FROZEN=true \
    BUNDLE_DEPLOYMENT=true \
    BUNDLE_WITHOUT="development:test" \
    BUNDLE_PATH=/usr/local/bundle

RUN bundle install

FROM ruby:4.0.6-alpine3.24

RUN apk add --no-cache ghostscript ghostscript-fonts \
    && addgroup -S app \
    && adduser -S -G app -h /home/app app \
    && mkdir -p /app /home/app \
    && chown -R app:app /app /home/app

WORKDIR /app

COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --chown=app:app . .

ENV RACK_ENV=production \
    BUNDLE_FROZEN=true \
    BUNDLE_DEPLOYMENT=true \
    BUNDLE_WITHOUT="development:test" \
    BUNDLE_PATH=/usr/local/bundle \
    HOME=/home/app

USER app

EXPOSE 8080

CMD ["bundle", "exec", "puma", "-b", "tcp://0.0.0.0:8080", "-e", "production"]
