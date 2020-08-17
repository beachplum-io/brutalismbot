ENV["DRYRUN"] = "1"
ENV["LOG_LEVEL"] = "WARN"

require "brutalismbot/stub"
load "lib/lambda.rb"

AUTH = Brutalismbot::Slack::Auth.stub
POST = Brutalismbot::Reddit::Post.stub
POST.mime_type = "image/jpeg"

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

    it "should run lambda.slack_push" do
      event = {
        "body" => POST.to_slack,
        "webhook_url" => "https://slack.webhook/",
      }
      runtest :slack_push, event: event
    end

    it "should run lambda.twitter_push" do
      event = POST.to_twitter.transform_keys(&:to_s)
      runtest :twitter_push, event: event
    end

    it "should run lambda.slack_install" do
      event = {"Records" => [{"Sns" => {"Message" => AUTH.to_json}}]}
      runtest :slack_install, event: event
    end

    it "should run lambda.slack_uninstall" do
      event = {"Records" => [{"Sns" => {"Message" => {"team_id" => "T1234568"}.to_json}}]}
      runtest :slack_uninstall, event: event
    end
  end
end
