FROM ruby:4.0.6-alpine3.24 AS build

RUN apk add --no-cache build-base

WORKDIR /app
COPY Gemfile Gemfile.lock ./
ENV BUNDLE_FROZEN=true
RUN bundle install

FROM ruby:4.0.6-alpine3.24

RUN apk add --no-cache ghostscript ghostscript-fonts \
    && addgroup -S app \
    && adduser -S -G app app \
    && mkdir -p /app \
    && chown -R app:app /app

WORKDIR /app
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY . .
RUN chown -R app:app /app

USER app

EXPOSE 8080

CMD ["bundle", "exec", "puma", "-b", "tcp://0.0.0.0:8080", "-e", "production"]
