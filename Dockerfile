ARG RUNTIME=ruby2.5

# Build Lambda package
FROM lambci/lambda:build-${RUNTIME} AS build
COPY lambda.rb Gemfile* /var/task/
ARG BUNDLE_SILENCE_ROOT_WARNING=1
RUN bundle install --path vendor/bundle/ --without development
RUN zip -r lambda.zip .

# Deploy
FROM lambci/lambda:build-${RUNTIME} AS deploy
COPY --from=hashicorp/terraform:0.12.1 /bin/terraform /bin/
COPY --from=build /var/task/lambda.zip .
COPY *.tf /var/task/
ARG AWS_ACCESS_KEY_ID
ARG AWS_DEFAULT_REGION=us-east-1
ARG AWS_SECRET_ACCESS_KEY
ARG TF_VAR_release
RUN terraform init
RUN terraform fmt -check
RUN terraform plan -out terraform.zip
CMD ["terraform", "apply", "terraform.zip"]

FROM lambci/lambda:${RUNTIME} AS runtime
COPY --from=build /var/task/lambda.rb .
COPY --from=build /var/task/vendor vendor
