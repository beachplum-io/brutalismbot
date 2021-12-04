namespace :states do
  desc 'Start dequeue state machine'
  task :dequeue do
    sh <<~SH
      terraform output -raw state_machine_reddit_dequeue_arn \
      | xargs aws stepfunctions start-execution --input '{}' --state-machine-arn \
      | jq
    SH
  end

  namespace :dequeue do
    desc 'Start dequeue state machine and open web console'
    task :open do
      sh <<~SH
        terraform output -raw state_machine_reddit_dequeue_arn \
        | xargs aws stepfunctions start-execution --input '{}' --state-machine-arn \
        | jq -r '"https://console.aws.amazon.com/states/home?#/executions/details/" + .executionArn' \
        | xargs open
      SH
    end
  end
end
