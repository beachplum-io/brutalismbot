
ENV["DRYRUN"] = "1"
ENV["LOG_LEVEL"] = "WARN"

require "brutalismbot/stub"
load "lib/lambda.rb"

BRUTALISMBOT.stub!

RSpec.describe "lambda" do
  def runtest(name, event:, context:nil)
    puts "\n=> #{name.upcase}"
    send name, event: event, context: context
  end

  context :lambda do
    it "should run lambda.test" do
      runtest :test, event: {}
    end
    it "should run lambda.reddit_pull" do
      runtest :reddit_pull, event: {}
    end

    it "should run lambda.slack_install" do
      event = {
        "Records" => [
          {
            "Sns" => {
              "Message" => Brutalismbot::Slack::Auth.stub.to_json,
            },
          },
        ],
      }
      runtest :slack_install, event: event
    end

    it "should run lambda.slack_push" do
      event = {
        "Content-Type" => "image/jpeg",
        "Post" => BRUTALISMBOT.posts.list.first.to_h,
        "Slack" => BRUTALISMBOT.slack.list.first.to_s3(prefix: BRUTALISMBOT.slack.prefix).slice(:bucket, :key),
      }
      runtest :slack_push, event: event
    end

    it "should run lambda.slack_uninstall" do
      event = {
        "Records" => [
          {
            "Sns" => {
              "Message" => {
                "token" => "<token>",
                "team_id" => "T1234568",
                "api_app_id" => "A12345678",
                "type" => "event_callback",
                "event_id" => "Ev12345678",
                "event_time" => 1553557314,
                "event" => {
                  "type" => "app_uninstalled",
                },
              }.to_json,
            },
          },
        ],
      }
      runtest :slack_uninstall, event: event
    end

    it "should run lambda.twitter_push" do
      event = {
        "Content-Type" => "image/jpeg",
        "Post" => BRUTALISMBOT.posts.list.first.to_h,
      }
      runtest :twitter_push, event: event
    end
  end
end
