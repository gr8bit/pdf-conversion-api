FROM ruby:4.0-alpine AS build

RUN apk add --no-cache build-base

WORKDIR /app
COPY Gemfile Gemfile.lock ./
RUN bundle install

FROM ruby:4.0-alpine

RUN apk add --no-cache ghostscript ghostscript-fonts

WORKDIR /app
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY . .

EXPOSE 8080

CMD ["bundle", "exec", "puma", "-p", "8080", "-e", "production"]
