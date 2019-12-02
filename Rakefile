ENV["DRYRUN"] = "1"

require "brutalismbot/stub"
require_relative "./lambda"

BRUTALISMBOT.stub!

def runtest(name, func)
  puts "\n=> #{name}"
  puts func.call
end

desc 'lambda.test'
task :test do
  runtest "TEST", -> { test event: {} }
end

desc 'lambda.pull'
task :pull do
  runtest "PULL", -> { pull }
end

desc 'lambda.push'
task :push do
  key   = URI.escape BRUTALISMBOT.posts.key_for BRUTALISMBOT.posts.last
  event = {
    "Records" => [
      {
        "s3" => {
          "bucket" => {"name" => "brutalismbot"},
          "object" => {"key"  => key},
        },
      },
    ],
  }
  runtest "PUSH", -> { push event: event }
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
    runtest "SLACK INSTALL", -> { slack_install event: event }
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
    runtest "SLACK UNINSTALL", -> { slack_uninstall event: event }
  end
end

task :slack => [:"slack:install", :"slack:uninstall"]

task :default => [:test, :pull, :push, :slack]
