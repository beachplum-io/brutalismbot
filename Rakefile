require 'dotenv/load'
require 'rake/clean'
require 'rspec/core/rake_task'

# Load tasks
Dir['tasks/*'].map do |task| load task end

# Create RSpec task
RSpec::Core::RakeTask.new :spec => :vendor

task :default => :spec

desc 'Run terraform init'
task :init => :'terraform:init'

desc 'Run terraform plan'
task :plan => :'terraform:plan'

desc 'Run terraform apply'
task :apply => :'terraform:apply'

desc 'Run terraform apply -auto-approve'
task :'apply:auto' => :'terraform:apply:auto'
