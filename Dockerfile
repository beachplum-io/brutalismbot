ARG RUNTIME=ruby2.5

# Build Lambda package
FROM lambci/lambda:build-${RUNTIME} AS build
COPY Gemfile* Rakefile lambda.rb /var/task/
ARG BUNDLE_SILENCE_ROOT_WARNING=1
RUN bundle install --path vendor/bundle/ --without development
RUN zip -r lambda.zip Gemfile* Rakefile lambda.rb vendor

# Run tests & Build deployment
FROM lambci/lambda:build-${RUNTIME} AS deploy
COPY --from=hashicorp/terraform:0.12.2 /bin/terraform /bin/
COPY --from=build /var/task/lambda.zip .
COPY terraform.tf .
ARG AWS_ACCESS_KEY_ID
ARG AWS_DEFAULT_REGION=us-east-1
ARG AWS_SECRET_ACCESS_KEY
ARG BUNDLE_SILENCE_ROOT_WARNING=1
ARG TF_VAR_release
RUN unzip lambda.zip
RUN bundle install
RUN bundle exec rake
RUN terraform init
RUN terraform fmt -check
RUN terraform plan -out terraform.zip
CMD ["terraform", "apply", "terraform.zip"]

# Runtime replica
FROM lambci/lambda:${RUNTIME} AS runtime
COPY --from=build /var/task/lambda.rb .
COPY --from=build /var/task/vendor vendor
