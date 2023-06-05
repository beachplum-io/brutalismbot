require 'aws-sdk-dynamodb'
require 'aws-sdk-eventbridge'
require 'aws-sdk-scheduler'
require 'yake/logger'
require 'yake/support'

require_relative 'slack'

Aws.config = { retry_limit: 5, retry_backoff: -> (c) { sleep(5) } }

class Home
  include Slack
  include Yake::Logger

  TABLE_NAME     = ENV['METRICS_NAMESPACE'] || 'brutalismbot-blue'
  EVENT_BUS_NAME = ENV['EVENT_BUS_NAME']    || 'brutalismbot-blue'
  SCHEDULE_GROUP = ENV['SCHEDULE_GROUP']    || 'brutalismbot-blue'

  QUEUES = {
    '/r/brutalism' => '/r/brutalism',
  }
  RULES = {
    'Bluesky' => "#{EVENT_BUS_NAME}-bluesky-send-post",
    'Slack'   => "#{EVENT_BUS_NAME}-slack-send-post",
    'Twitter' => "#{EVENT_BUS_NAME}-twitter-send-post",
  }
  SCHEDULES = {
    'Reddit' => "#{SCHEDULE_GROUP}-reddit-pop",
  }

  def initialize(credentials: nil)
    credentials ||= Aws::CredentialProviderChain.new.resolve
    @dynamodb     = Aws::DynamoDB::Client.new(credentials: credentials)
    @eventbridge  = Aws::EventBridge::Client.new(credentials: credentials)
    @scheduler    = Aws::Scheduler::Client.new(credentials: credentials)
  end

  def view
    { type: 'home', callback_id: 'home', blocks: blocks }
  end

  def blocks
    [
      *blocks_refresh,
      *blocks_queues,
      *blocks_schedules,
      *blocks_triggers,
    ]
  end

  def blocks_refresh
    refresh = Action.button(action_id: 'refresh_home', value: 'home', text: 'Refresh'.plain_text)
    [Block.actions(elements: [refresh])]
  end

  def blocks_queues
    Enumerator.new do |enum|
      enum.yield Block.header(text: 'Queues'.plain_text)

      QUEUES.each do |text, name|
        size    = queue_size(name)
        squares = size.zero? ? '-' : size.times.map { ' :large_purple_square:' }.join
        text    = [text, squares].join.plain_text
        button  = Action.button(action_id: 'pop', value: name, text: 'Pop'.plain_text)
        enum.yield Block.section(text: text, accessory: button)
      end
    end
  end

  def blocks_schedules
    Enumerator.new do |enum|
      enum.yield Block.header(text: 'Schedules'.plain_text)
      SCHEDULES.each do |text, name|
        schedule = get_schedule(name)
        button   = get_schedule_button(schedule)
        enum.yield Block.section(text: text.plain_text, accessory: button)
      end
    end
  end

  def blocks_triggers
    Enumerator.new do |enum|
      enum.yield Block.header(text: 'Rules'.plain_text)
      RULES.each do |text, name|
        rule   = get_rule(name)
        button = get_rule_button(rule)
        enum.yield Block.section(text: text.plain_text, accessory: button)
      end
    end
  end

  def get_rule(name)
    params = { event_bus_name: EVENT_BUS_NAME, name: name }
    logger.info("events:DescribeRule #{params.to_json}")
    @eventbridge.describe_rule(**params)
  end

  def get_rule_button(rule)
    value = { event_bus_name: rule.event_bus_name, name: rule.name }.to_json
    case rule.state
    when 'ENABLED'
      Action.button(action_id: 'disable_rule', value: value, text: 'Enabled'.plain_text)
    else
      Action.button(action_id: 'enable_rule', value: value, text: 'Disabled'.plain_text, style: 'danger')
    end
  end

  def get_schedule(name)
    params = { group_name: SCHEDULE_GROUP, name: name }
    logger.info("scheduler:GetSchedule #{params.to_json}")
    @scheduler.get_schedule(**params)
  end

  def get_schedule_button(schedule)
    value = { group_name: schedule.group_name, name: schedule.name }.to_json
    case schedule.state
    when 'ENABLED'
      Action.button(action_id: 'disable_schedule', value: value, text: 'Enabled'.plain_text)
    else
      Action.button(action_id: 'enable_schedule', value: value, text: 'Disabled'.plain_text, style: 'danger')
    end
  end

  def queue_size(name)
    params = {
      table_name: TABLE_NAME,
      key: { Id: name, Kind: 'cursor' },
      projection_expression: 'QueueSize',
    }
    logger.info("dynamodb:GetItem #{params.to_json}")
    @dynamodb.get_item(**params).item['QueueSize'].to_i
  end
end
