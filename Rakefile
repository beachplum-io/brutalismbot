require 'dotenv/load'
require 'rspec/core/rake_task'

task :default => %i[vendor spec]

RSpec::Core::RakeTask.new :spec

desc 'Run terraform plan'
task :plan => %i[terraform:plan]

desc 'Run terraform apply'
task :apply => %i[terraform:apply]

desc 'Run RSpec code examples'
task :spec

desc 'Vendor Lambda dependencies'
task :vendor => %i[lib/vendor]

namespace :terraform do
  desc 'Run terraform plan'
  task :plan => :init do
    sh %{terraform plan -detailed-exitcode}
  end

  desc 'Run terraform apply'
  task :apply => :init do
    sh %{terraform apply}
  end

  namespace :apply do
    desc 'Run terraform auto -auto-approve'
    task :auto => :init do
      sh %{terraform apply -auto-approve}
    end
  end

  task :init => '.terraform'

  directory '.terraform' do
    sh %{terraform init}
  end
end

file 'lib/vendor' => 'lib/Gemfile' do
  cd 'lib' do
    rm_rf 'vendor'
    sh    'bundle'
  end
end
