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

  namespace :reset do
    desc 'Taint State Machines'
    task :'state-machines' do
      sh <<~SH
        terraform state list | grep aws_sfn_state_machine | xargs -n1 terraform taint
        terraform state list | grep aws_sfn_state_machine | tac | xargs -n1 terraform apply -auto-approve -target 
      SH
    end
  end

  directory '.terraform' do
    sh 'terraform init'
  end
end
