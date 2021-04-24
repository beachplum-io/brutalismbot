require "dotenv/load"
require "rake/clean"
require "rspec/core/rake_task"
RSpec::Core::RakeTask.new

REPO = "brutalismbot/brutalismbot"

directory ".docker"
directory "pkg"
CLOBBER.include ".docker", "pkg"

task :default => %i[zip]
task :zip     => %i[function:zip layer:zip]
task :clean   => %i[docker:clean]
task :clobber => %i[clean]

def iidfile(target)
  desc "Build #{REPO}:#{target} image"
  task target => ".docker/#{target}"

  file ".docker/#{target}"  do |f|
    sh "docker build --iidfile #{f.name} --tag #{REPO}:#{target} --target #{target} ."
  end
end

namespace :docker do
  %i[zip dev].each {|target| iidfile target }
  file ".docker/zip" => %w[Dockerfile Gemfile Gemfile.lock], order_only: ".docker"
  file ".docker/dev" => %w[.docker/zip lib/lambda.rb]

  task :clean do
    sh "docker image ls --quiet #{REPO} | uniq | xargs docker image rm --force"
  end
end

namespace :function do
  desc "Build function zipfile"
  task :zip => "pkg/function.zip"

  file "pkg/function.zip" => %w[lib/lambda.rb], order_only: "pkg" do |f|
    Dir.chdir("lib") { sh "zip ../#{f.name} lambda.rb" }
  end
end

namespace :layer do
  desc "Build layer zipfile"
  task :zip => "pkg/layer.zip"

  desc "Publish Lambda Layer package"
  task :publish => :zip do
    sh <<~EOS
      aws lambda publish-layer-version \
      --compatible-runtimes ruby2.7 \
      --description 'Brutalismbot v2' \
      --layer-name brutalismbot \
      --zip-file fileb://pkg/layer.zip
    EOS
  end

  file "pkg/layer.zip" => ".docker/zip" do |f|
    sh "docker run --rm --entrypoint cat $(cat .docker/zip) #{File.basename f.name} > #{f.name}"
  end
end

namespace :terraform do
  desc "Run terraform plan"
  task :plan => :init do
    sh %{terraform plan -detailed-exitcode}
  end

  desc "Run terraform apply"
  task :apply => :init do
    sh %{terraform apply}
  end

  namespace :apply do
    desc "Run terraform auto -auto-approve"
    task :auto => :init do
      sh %{terraform apply -auto-approve}
    end
  end

  task :init => ".terraform"

  directory ".terraform" do
    sh %{terraform init}
  end
end
