require "dotenv/load"
require "rake/clean"

namespace :docker do
  %i[zip dev].each do |name|
    iidfile = "pkg/#{name}.iid"

    desc "Build #{iidfile}"
    task name => iidfile

    file iidfile do |f|
      sh <<~EOS
        docker build \
        --iidfile #{f.name} \
        --tag brutalismbot/brutalismbot:#{name} \
        --target #{name} \
        .
      EOS
    end

    file "pkg/zip.iid" => ["pkg"] + Dir["Dockerfile", "Gemfile*", "lib/*"]
    file "pkg/dev.iid" => "pkg/zip.iid"
    CLEAN.include iidfile
  end
end

namespace :zip do
  %i[function layer].each do |name|
    iidfile = "pkg/zip.iid"
    zipfile = "pkg/#{name}.zip"

    desc "Build #{zipfile}"
    task name => zipfile

    file zipfile => iidfile do |f|
      sh "docker run --rm --entrypoint cat $(cat #{iidfile}) #{name}.zip > #{f.name}"
    end
  end
end

task :docker  => %i[docker:zip docker:dev]
task :zip     => %i[zip:function zip:layer]
task :default => :zip
directory "pkg"
CLOBBER.include "pkg"

require "rspec/core/rake_task"
RSpec::Core::RakeTask.new
# task :spec => "pkg/dev.iid"
