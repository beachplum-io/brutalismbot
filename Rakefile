require "dotenv/load"
require "rake/clean"
require "rspec/core/rake_task"
RSpec::Core::RakeTask.new

REPO = "brutalismbot/brutalismbot"

directory ".docker"
directory "pkg"
CLEAN.include ".docker", "pkg"

task :zip => %i[function layer]

def iidfile(target)
  desc "Build #{REPO}:#{target} image"
  task target => ".docker/#{target}"

  file ".docker/#{target}"  do |f|
    sh "docker build --iidfile #{f.name} --tag #{REPO}:#{target} --target #{target} ."
  end
end

task :docker => %i[docker:zip docker:dev]
namespace :docker do
  %i[zip dev].each {|target| iidfile target }
  file ".docker/zip" => ".docker"
  file ".docker/zip" => Dir["Dockerfile", "Gemfile*", "lib/*"]
  file ".docker/dev" => ".docker/zip"

  task :clean do
    sh "docker image ls --quiet #{REPO} | uniq | xargs docker image rm --force"
  end
end

task :function => %i[function:build]
namespace :function do
  desc "Build function zipfile"
  task :build => "pkg/function.zip"

  file "pkg/function.zip" => ".docker/zip" do |f|
    sh "docker run --rm --entrypoint cat $(cat .docker/zip) #{File.basename f.name} > #{f.name}"
  end
end

task :layer => %i[layer:build]
namespace :layer do
  desc "Build layer zipfile"
  task :build => "pkg/layer.zip"

  desc "Publish Lambda Layer package"
  task :publish => :build do
    sh <<~EOS
      aws lambda publish-layer-version \
      --compatible-runtimes ruby2.7 \
      --description 'Brutalismbot v1.8' \
      --layer-name brutalismbot \
      --zip-file fileb://pkg/layer.zip
    EOS
  end

  file "pkg/layer.zip" => ".docker/zip" do |f|
    sh "docker run --rm --entrypoint cat $(cat .docker/zip) #{File.basename f.name} > #{f.name}"
  end
end
