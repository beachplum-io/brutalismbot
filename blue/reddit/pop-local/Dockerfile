FROM ruby:alpine
WORKDIR /r/brutalism
COPY . .
RUN apk add --no-cache build-base && bundle install
CMD ["rake"]
