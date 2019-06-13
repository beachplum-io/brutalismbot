ARG RUNTIME=ruby2.5

# Build Lambda package
FROM lambci/lambda:build-${RUNTIME} AS build
COPY Gemfile* lambda.rb /var/task/
ARG BUNDLE_SILENCE_ROOT_WARNING=1
RUN bundle install --path vendor/bundle/ --without development
RUN zip -r lambda.zip Gemfile* lambda.rb vendor

# Run tests
FROM lambci/lambda:build-${RUNTIME} AS test
COPY --from=build /var/task/ .
COPY Rakefile .
ARG AWS_ACCESS_KEY_ID
ARG AWS_DEFAULT_REGION=us-east-1
ARG AWS_SECRET_ACCESS_KEY
ARG BUNDLE_SILENCE_ROOT_WARNING=1
RUN bundle install --with development
RUN bundle exec rake

# Build deployment
FROM lambci/lambda:build-${RUNTIME} AS plan
COPY --from=hashicorp/terraform:0.12.2 /bin/terraform /bin/
COPY --from=build /var/task/ .
COPY terraform.tf .
ARG AWS_ACCESS_KEY_ID
ARG AWS_DEFAULT_REGION=us-east-1
ARG AWS_SECRET_ACCESS_KEY
ARG TF_VAR_release
RUN terraform init
RUN terraform fmt -check
RUN terraform plan -out terraform.zip
CMD ["terraform", "apply", "terraform.zip"]
