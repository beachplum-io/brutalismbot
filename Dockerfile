FROM public.ecr.aws/lambda/ruby
RUN dnf install -y gcc
ENV BUNDLE_SILENCE_ROOT_WARNING=1
VOLUME /root/.bundle
VOLUME /var/task
ENTRYPOINT ["bundle"]
