ARG RUNTIME=ruby2.5
ARG TERRAFORM_VERSION=latest

FROM lambci/lambda:build-${RUNTIME} AS build
COPY lambda.rb .
RUN zip -r lambda.zip lambda.rb

FROM lambci/lambda:build-${RUNTIME} AS test
COPY Gemfile* lambda.rb ./
ARG AWS_ACCESS_KEY_ID
ARG AWS_DEFAULT_REGION=us-east-1
ARG AWS_SECRET_ACCESS_KEY
ARG BUNDLE_SILENCE_ROOT_WARNING=1
RUN bundle install
COPY Rakefile .
RUN bundle exec rake

FROM hashicorp/terraform:${TERRAFORM_VERSION} AS plan
WORKDIR /var/task/
RUN apk add --no-cache python3 && pip3 install awscli
COPY --from=test /var/task/ .
ARG AWS_ACCESS_KEY_ID
ARG AWS_DEFAULT_REGION=us-east-1
ARG AWS_SECRET_ACCESS_KEY
ARG TF_VAR_release
ARG TF_VAR_twitter_access_token
ARG TF_VAR_twitter_access_token_secret
ARG TF_VAR_twitter_consumer_key
ARG TF_VAR_twitter_consumer_secret
COPY terraform.tf .
RUN terraform init
RUN terraform fmt -check
RUN terraform plan -out terraform.zip
CMD ["apply", "terraform.zip"]
