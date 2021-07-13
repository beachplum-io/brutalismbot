require 'dotenv/load'
require 'rake/clean'
require 'rspec/core/rake_task'

task :default => :spec

# Load tasks
Dir['tasks/*'].map do |task| load task end

# Create RSpec task
RSpec::Core::RakeTask.new :spec => :vendor
