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

desc 'lambda.pull'
task :pull do
  runtest("PULL") { pull }
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
  runtest("PUSH") { push event: event }
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

task :slack => %i[slack:install slack:uninstall]

task :default => %i[test pull push slack]
