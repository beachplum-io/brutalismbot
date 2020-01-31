ARG RUNTIME=ruby2.5
ARG TERRAFORM_VERSION=latest

# Build deployment package
FROM lambci/lambda:build-${RUNTIME} AS build
WORKDIR /opt/ruby/
COPY Gemfile* ./
RUN bundle config --local path .
RUN bundle config --local silence_root_warning 1
RUN bundle config --local without development
RUN bundle
RUN mv ruby gems
WORKDIR /var/task/
COPY lib .
WORKDIR /var/task/pkg/
WORKDIR /opt/
RUN zip -r /var/task/pkg/layer.zip ruby
WORKDIR /var/task/
RUN zip -r /var/task/pkg/function.zip lambda.rb

# Create runtime environment for running tests
FROM lambci/lambda:${RUNTIME} AS dev
COPY --from=build /opt/ /opt/

# Run rake tests
FROM lambci/lambda:build-${RUNTIME} AS test
RUN gem install rake -v 13.0.1
COPY --from=build /opt/ /opt/
COPY Rakefile .
ARG AWS_ACCESS_KEY_ID
ARG AWS_DEFAULT_REGION=us-east-1
ARG AWS_SECRET_ACCESS_KEY
RUN rake

# Plan deployment
FROM hashicorp/terraform:${TERRAFORM_VERSION} AS plan
WORKDIR /var/task/
COPY terraform terraform
COPY terraform.tf .
RUN terraform fmt -check
ARG AWS_ACCESS_KEY_ID
ARG AWS_DEFAULT_REGION=us-east-1
ARG AWS_SECRET_ACCESS_KEY
RUN terraform init
ARG TF_VAR_release
ARG TF_VAR_twitter_access_token
ARG TF_VAR_twitter_access_token_secret
ARG TF_VAR_twitter_consumer_key
ARG TF_VAR_twitter_consumer_secret
RUN terraform plan -out terraform.zip
CMD ["apply", "terraform.zip"]
