ARG RUBY=2.7

# Build deployment package
FROM lambci/lambda:build-ruby${RUBY} AS zip
COPY Gemfile* ./
RUN bundle config --local path ruby
RUN bundle config --local silence_root_warning 1
RUN bundle config --local without development
RUN bundle
RUN mv ruby/ruby ruby/gems
RUN zip -9r layer.zip ruby Gemfile*

# Create runtime environment for running tests
FROM lambci/lambda:ruby${RUBY} AS dev
COPY --from=zip /var/task/ruby /opt/ruby
COPY lib .
