require 'rake/clean'

CLEAN.include 'lib/vendor'

desc 'Vendor dependencies'
task :vendor => 'lib/vendor'

directory 'lib/vendor' => 'lib/Gemfile' do
  cd 'lib' do
    rm_rf 'vendor'
    sh    'bundle'
  end
end
