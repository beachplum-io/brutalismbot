pwd = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(pwd) unless $LOAD_PATH.include?(pwd)

ENV["DRYRUN"] = "1"

require "brutalismbot/stub"
require "lambda"

BRUTALISMBOT.stub!

def runtest(name, &block)
  puts "\n=> #{name}"
  puts block.call if block_given?
end

desc 'lambda.test'
task :test do
  runtest("TEST") { test event: {} }
end

namespace :reddit do
  desc 'lambda.reddit_pull'
  task :pull do
    runtest("PULL") { reddit_pull }
  end
end

namespace :slack do
  desc 'lambda.slack_install'
  task :install do
    event = {
      "Records" => [
        {
          "Sns" => {
            "Message" => Brutalismbot::Slack::Auth.stub.to_json,
          },
        },
      ],
    }
    runtest("SLACK INSTALL") { slack_install event: event }
  end

  desc 'lambda.slack_push'
  task :push do
    event = {
      "Post"  => BRUTALISMBOT.posts.list.first.to_s3(prefix: BRUTALISMBOT.posts.prefix).slice(:bucket, :key),
      "Slack" => BRUTALISMBOT.slack.list.first.to_s3(prefix: BRUTALISMBOT.slack.prefix).slice(:bucket, :key),
    }
    runtest("SLACK PUSH") { slack_push event: event }
  end

  desc 'lambda.slack_uninstall'
  task :uninstall do
    event = {
      "Records" => [
        {
          "Sns" => {
            "Message" => {
              token:      "<token>",
              team_id:    "T1234568",
              api_app_id: "A12345678",
              type:       "event_callback",
              event_id:   "Ev12345678",
              event_time: 1553557314,
              event: {
                type: "app_uninstalled",
              },
            }.to_json,
          },
        },
      ],
    }
    runtest("SLACK UNINSTALL") { slack_uninstall event: event }
  end
end

namespace :twitter do
  desc 'lambda.twitter_push'
  task :push do
    event = {
      "Post" => BRUTALISMBOT.posts.list.first.to_s3(prefix: BRUTALISMBOT.posts.prefix).slice(:bucket, :key),
    }
    runtest("TWITTER PUSH") { twitter_push event: event }
  end
end

task :reddit  => %i[reddit:pull]
task :slack   => %i[slack:install slack:push slack:uninstall]
task :twitter => %i[twitter:push]
task :default => %i[test reddit slack twitter]
