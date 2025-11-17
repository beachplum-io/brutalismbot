FROM public.ecr.aws/lambda/ruby
RUN dnf install -y gcc
ENV BUNDLE_CLEAN=true
ENV BUNDLE_PATH=vendor/bundle
ENV BUNDLE_SILENCE_ROOT_WARNING=1
ENV BUNDLE_WITHOUT=development
VOLUME /root/.bundle
VOLUME /var/task
ENTRYPOINT ["bundle"]
