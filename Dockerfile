ARG RUNTIME=ruby2.5
ARG TERRAFORM_VERSION=latest

FROM lambci/lambda:build-${RUNTIME} AS build
COPY . .
ARG BUNDLE_SILENCE_ROOT_WARNING=1
RUN bundle install --path vendor/bundle/ --without development
RUN zip -r lambda.zip Gemfile* lambda.rb vendor

FROM lambci/lambda:build-${RUNTIME} AS test
COPY --from=build /var/task/ .
ARG BUNDLE_SILENCE_ROOT_WARNING=1
RUN bundle install --with development
RUN bundle exec rake

FROM hashicorp/terraform:${TERRAFORM_VERSION} AS plan
WORKDIR /var/task/
RUN apk add --no-cache python3 && pip3 install awscli
COPY --from=test /var/task/ .
ARG AWS_ACCESS_KEY_ID
ARG AWS_DEFAULT_REGION=us-east-1
ARG AWS_SECRET_ACCESS_KEY
ARG TF_VAR_release
RUN terraform init
RUN terraform fmt -check
RUN terraform plan -out terraform.zip
CMD ["apply", "terraform.zip"]
