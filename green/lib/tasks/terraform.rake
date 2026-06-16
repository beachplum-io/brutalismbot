# frozen_string_literal: true

namespace :terraform do
  desc 'Bundle Lambda functions'
  task :build do
    sh %{docker image build --tag brutalismbot .}
    Dir["**/functions/*/Gemfile"].each do |gemfile|
      dirname = File.dirname gemfile
      rm_f "#{gemfile}.lock"
      sh %{docker container run --rm --tty --volume $PWD/#{dirname}:/var/task brutalismbot install}
    end
    sh %{docker image rm brutalismbot}
  end
end
