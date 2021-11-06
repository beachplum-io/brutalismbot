def tail(function_name, args)
  sh %{aws logs tail /aws/lambda/#{ function_name } --follow --since #{ args[:'15m'] || '15m' }}
end

namespace :logs do
  desc 'Tail HTTP API Lambda logs'
  task :'http-api', [:'15m'] do |t,args|
    tail 'brutalismbot-slack-api-proxy', args
  end

  namespace :'http-api' do
    desc 'Tail HTTP API Lambda logs [beta]'
    task :beta, [:'15m'] do |t,args|
      tail 'brutalismbot-slack-beta-api-proxy', args
    end
  end
end
