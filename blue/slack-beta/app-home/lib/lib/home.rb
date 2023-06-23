require 'erb'
require 'yaml'

require 'aws-sdk-dynamodb'
require 'aws-sdk-eventbridge'
require 'aws-sdk-scheduler'
require 'yake/logger'
require 'yake/support'

Aws.config = { retry_limit: 5, retry_backoff: -> (c) { sleep(5) } }

class Home
  include Yake::Logger

  TABLE_NAME     = ENV['METRICS_NAMESPACE'] || 'brutalismbot-blue'
  EVENT_BUS_NAME = ENV['EVENT_BUS_NAME']    || 'brutalismbot-blue'
  SCHEDULE_GROUP = ENV['SCHEDULE_GROUP']    || 'brutalismbot-blue'

  QUEUES = {
    '/r/brutalism' => '/r/brutalism',
    'backlog'      => 'backlog',
  }
  RULES = {
    'Bluesky' => "#{EVENT_BUS_NAME}-bluesky-send-post",
    'Slack'   => "#{EVENT_BUS_NAME}-slack-send-post",
    'Twitter' => "#{EVENT_BUS_NAME}-twitter-send-post",
  }
  SCHEDULES = {
    'Reddit' => "#{SCHEDULE_GROUP}-reddit-pop",
  }

  TEMPLATE = File.read(File.expand_path('home.yml.erb', File.dirname(__FILE__)))

  class Queue    < Struct.new('Queue',    :name, :value)            ; end
  class Schedule < Struct.new('Schedule', :name, :value, :enabled?) ; end
  class Rule     < Struct.new('Rule',     :name, :value, :enabled?) ; end

  def initialize(credentials: nil)
    credentials ||= Aws::CredentialProviderChain.new.resolve
    @dynamodb     = Aws::DynamoDB::Client.new(credentials: credentials)
    @eventbridge  = Aws::EventBridge::Client.new(credentials: credentials)
    @scheduler    = Aws::Scheduler::Client.new(credentials: credentials)
  end

  def view(user_id)
    view_yaml = ERB.new(TEMPLATE).result(binding)
    YAML.safe_load(view_yaml)
  end

  def queues
    QUEUES.map do |name, key|
      Queue.new(name: name, value: queue_size(key))
    end
  end

  def schedules
    SCHEDULES.map do |name, key|
      schedule = get_schedule(key)
      value    = { GroupName: schedule.group_name, Name: schedule.name }
      enabled  = schedule.state == 'ENABLED'
      Schedule.new(name: name, value: value, enabled?: enabled)
    end
  end

  def rules
    RULES.map do |name, key|
      rule    = get_rule(key)
      value   = { EventBusName: rule.event_bus_name, Name: rule.name }
      enabled = rule.state == 'ENABLED'
      Schedule.new(name: name, value: value, enabled?: enabled)
    end
  end

  def get_rule(name)
    params = { event_bus_name: EVENT_BUS_NAME, name: name }
    logger.info("events:DescribeRule #{params.to_json}")
    @eventbridge.describe_rule(**params)
  end

  def get_schedule(name)
    params = { group_name: SCHEDULE_GROUP, name: name }
    logger.info("scheduler:GetSchedule #{params.to_json}")
    @scheduler.get_schedule(**params)
  end

  def queue_size(name)
    params = {
      table_name: TABLE_NAME,
      key: { Id: name, Kind: 'cursor' },
      projection_expression: 'QueueSize',
    }
    logger.info("dynamodb:GetItem #{params.to_json}")
    @dynamodb.get_item(**params).item['QueueSize'].to_i rescue 0
  end
end
