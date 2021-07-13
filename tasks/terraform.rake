require 'dotenv/load'
require 'rake/clean'

CLOBBER.include '.terraform', 'pkg'

namespace :terraform do
  desc 'Run terraform plan'
  task :plan => :init do
    sh 'terraform plan -detailed-exitcode'
  end

  desc 'Run terraform apply'
  task :apply => :init do
    sh 'terraform apply'
  end

  namespace :apply do
    desc 'Run terraform auto -auto-approve'
    task :auto => :init do
      sh 'terraform apply -auto-approve'
    end
  end

  desc 'Run terraform init'
  task :init => %i[vendor .terraform]

  directory '.terraform' do
    sh 'terraform init'
  end
end
