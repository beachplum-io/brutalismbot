namespace :states do
  desc 'Start dequeue state machine'
  task :dequeue do
    sh <<~SH
      terraform output -raw state_machine_reddit_dequeue_arn \
      | xargs aws stepfunctions start-execution --input '{}' --state-machine-arn
    SH
  end
end
