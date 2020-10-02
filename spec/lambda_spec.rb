ENV["DRYRUN"] = "1"
ENV["LOG_LEVEL"] = "WARN"

require "brutalismbot/stub"

Aws.config[:secretsmanager] = {
  stub_responses: {
    get_secret_value: {
      secret_string: {}.to_json
    }
  }
}

module URI
  def self.open(name, *rest, &block)
    Tempfile.new
  end
end

load "lib/lambda.rb"

BRUTALISMBOT.stub!

RSpec.describe "lambda" do
  def runtest(name, event:nil, context:nil)
    puts "\n=> #{name.upcase}"
    send name, event: (event || {}), context: context
  end

  context :lambda do
    it "should run lambda.test" do
      runtest :test
    end

    it "should run lambda.reddit_pull" do
      runtest :reddit_pull
    end

    it "should run lambda.slack_push" do
      bucket = "brutalismbot"
      prefix = "data/test/posts/"
      key    = BRUTALISMBOT.posts.client.list_objects_v2(bucket: bucket, prefix: prefix).contents.first.key
      event  = { "bucket" => bucket, "key" => key, "webhook_url" => "https://slack.webhook/" }
      runtest :slack_push, event: event
    end

    it "should run lambda.twitter_push" do
      bucket = "brutalismbot"
      prefix = "data/test/posts/"
      key    = BRUTALISMBOT.posts.client.list_objects_v2(bucket: bucket, prefix: prefix).contents.first.key
      event  = { "bucket" => bucket, "key" => key }
      runtest :twitter_push, event: event
    end

    it "should run lambda.slack_install" do
      auth = BRUTALISMBOT.slack.list.first
      event = { "Records" => [ { "Sns" => { "Message" => auth.to_json } } ] }
      runtest :slack_install, event: event
    end

    it "should run lambda.slack_uninstall" do
      event = { "Records" => [ { "Sns" => { "Message" => { "team_id" => "T1234568" }.to_json } } ] }
      runtest :slack_uninstall, event: event
    end
  end
end
