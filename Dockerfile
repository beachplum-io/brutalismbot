ARG RUNTIME=ruby2.5

FROM lambci/lambda:build-${RUNTIME} AS build
COPY lambda.rb Gemfile* /var/task/
ARG BUNDLE_SILENCE_ROOT_WARNING=1
RUN bundle install --path vendor/bundle/ --without aws

FROM build AS plan
COPY --from=hashicorp/terraform:0.12.1 /bin/terraform /bin/
COPY *.tf /var/task/
ARG AWS_ACCESS_KEY_ID
ARG AWS_DEFAULT_REGION=us-east-1
ARG AWS_SECRET_ACCESS_KEY
ARG PLANFILE=terraform.tfplan
ARG TF_VAR_release
RUN zip -r lambda.zip Gemfile* lambda.rb vendor
RUN terraform init
RUN terraform fmt -check
RUN terraform plan -out ${PLANFILE}

FROM lambci/lambda:${RUNTIME} AS runtime
COPY --from=build /var/task/ .
