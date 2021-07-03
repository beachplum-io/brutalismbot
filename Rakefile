require "bundler/setup"
Bundler.require

HANDLERS = Dir["lib/*.rb"].map { |x| x[/lib\/(.*?).rb/, 1] }

task :default => %i[spec]

desc "Run terraform plan"
task :plan => %i[terraform:plan]

desc "Run terraform apply"
task :apply => %i[terraform:apply]

desc "Run RSpec code examples"
task :spec => HANDLERS.map { |x| :"spec:#{ x }" }

namespace :spec do
  HANDLERS.each do |handler|
    desc "Run RSpec code examples for #{ handler }"
    RSpec::Core::RakeTask.new handler do |t|
      t.pattern = "spec/**{,/*/**}/#{ handler }_spec.rb"
    end
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
