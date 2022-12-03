require 'aws-sdk-lambda'
require 'aws-sdk-cloudwatch'
require 'aws-sdk-eventbridge'
require 'aws-sdk-states'
require 'yake/logger'
require 'yake/support'

require_relative 'slack'

Aws.config = { retry_limit: 5, retry_backoff: -> (c) { sleep(5) } }

class Home
  include Yake::Logger

  def initialize(credentials: nil)
    @credentials = credentials || Aws::CredentialProviderChain.new.resolve
    @cloudwatch  = Aws::CloudWatch::Client.new(credentials: @credentials)
    @eventbridge = Aws::EventBridge::Client.new(credentials: @credentials)
    @lambda      = Aws::Lambda::Client.new(credentials: @credentials)
    @states      = Aws::States::Client.new(credentials: @credentials)
  end

  def view
    { type: 'home', callback_id: 'home', blocks: blocks }
  end

  def blocks
    blocks_queue_size +
    blocks_errors(:state_machine_errors, 'State Machine Errors') +
    blocks_errors(:lambda_errors, 'Lambda Headers') +
    blocks_actions
  end

  def dequeue_state
    params = { name: 'brutalismbot-reddit-dequeue' }
    logger.info("events:DescribeRule #{params.to_json}")
    @eventbridge.describe_rule(**params).state
  end

  def lambda_errors
    errors = {}

    logger.info('lambda:ListFunctions')
    @lambda.list_functions.map do |page|
      page.functions.map(&:function_name).map do |function_name|
        if function_name.start_with?('brutalismbot-')
          Thread.new do
            params = {
              dimensions:     [ { name: 'FunctionName', value: function_name } ],
              end_time:       UTC.now.iso8601,
              metric_name:    'Errors',
              namespace:      'AWS/Lambda',
              period:         3600,
              start_time:     UTC.now - 1.week,
              statistics:     ['Sum'],
              unit:           'Count',
            }
            logger.info("cloudwatch:GetMetricStatistics #{params.to_json}")
            sum = @cloudwatch.get_metric_statistics(**params).datapoints.map(&:sum).sum.to_i

            errors[function_name] = sum
          end
        end
      end.compact
    end.flatten.each(&:join)

    errors
  end

  def queue_size
    params = {
      dimensions:     [ { name: "QueueName", value: "/r/brutalism" } ],
      end_time:       UTC.now.iso8601,
      metric_name:    'QueueSize',
      namespace:      'Brutalismbot',
      period:         3600,
      start_time:     UTC.now - 1.day,
      statistics:     ['Maximum'],
      unit:           'Count',
    }
    logger.info("cloudwatch:GetMetricStatistics #{params.to_json}")
    @cloudwatch.get_metric_statistics(**params).datapoints.max_by(&:timestamp).maximum.to_i
  end

  def state_machine_errors
    errors = {}

    logger.info('states:ListStateMachines')
    @states.list_state_machines.map do |page|
      page.state_machines.map(&:state_machine_arn).map do |state_machine_arn|
        name = state_machine_arn.split(/:/).last
        if name.start_with?('brutalismbot-')
          Thread.new do
            params = {
              dimensions:     [ { name: 'StateMachineArn', value: state_machine_arn } ],
              end_time:       UTC.now.iso8601,
              metric_name:    'ExecutionsFailed',
              namespace:      'AWS/States',
              period:         3600,
              start_time:     UTC.now - 1.week,
              statistics:     ['Sum'],
              unit:           'Count',
            }
            logger.info("cloudwatch:GetMetricStatistics #{params.to_json}")
            sum = @cloudwatch.get_metric_statistics(**params).datapoints.map(&:sum).sum.to_i

            errors[name] = sum
          end
        end
      end.compact
    end.flatten.each(&:join)

    errors
  end

  private

  def blocks_errors(method, header)
    flawless = -> (_,v) { v.zero? }
    blockify = -> (k,v) { Slack::Block.section(fields: [k.bold.mrkdwn, v.to_s.mrkdwn]) }
    deprefix = -> (key) { key.delete_prefix('brutalismbot-') }

    errors = send(method).reject(&flawless).sort.to_h.transform_keys(&deprefix)
    if errors.any?
      [
        Slack::Block.header(text: header.plain_text),
        *errors.reject(&flawless).map(&blockify)
      ]
    else
      []
    end
  end

  def blocks_queue_size
    squares = queue_size.zero? ? "-" : queue_size.times.map { ":large_yellow_square:" }.join(" ")
    [
      Slack::Block.header(text: 'Queue Size'.plain_text),
      Slack::Block.section(fields: [ squares.mrkdwn ]),
    ]
  end

  def blocks_actions
    refresh_button = Slack::Action.button(:refresh, value: 'refresh', text: 'Refresh'.plain_text)
    state_button   = case dequeue_state
    when 'ENABLED'  then [ 'Disable', :danger  ]
    when 'DISABLED' then [ 'Enable',  :primary ]
    end.then do |text, style|
      Slack::Action.button(:enable_disable, style, value: text.downcase, text: text.plain_text)
    end

    [ Slack::Block.actions(:state, elements: [ refresh_button, state_button ]) ]
  end
end
