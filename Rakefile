ENV["DRYRUN"]     = "1"
ENV["MIN_TIME"] ||= (Time.now.utc.to_i - 36000).to_s
require_relative "./lambda"

def runtest(name, func)
  puts "\n=> #{name}"
  puts func.call
end

desc 'lambda.test'
task :test do
  runtest "TEST", -> { test event: nil, context: nil }
end

desc 'lambda.install'
task :install do
  event = {
    "Records" => [
      {
        "Sns" => {
          "Message" => {
            ok:           true,
            access_token: "<token>",
            scope:        "identify,incoming-webhook",
            user_id:      "<user>",
            team_name:    "<team>",
            team_id:      "T12345678",
            incoming_webhook: {
              channel:           "#brutalism",
              channel_id:        "C12345678",
              configuration_url: "https://team.slack.com/services/B12345678",
              url:               "https://hooks.slack.com/services/T12345678/B12345678/123456781234567812345678",
            },
            scopes: [
              "identify",
              "incoming-webhook",
            ],
          }.to_json,
        },
      },
    ],
  }
  runtest "INSTALL", -> { install event: event, context: nil }
end

desc 'lambda.cache'
task :cache do
  runtest "CACHE", -> { cache event: nil, context: nil }
end

desc 'lambda.mirror'
task :mirror do
  event = {
    "Records" => [
      {
        "s3" => {
          "bucket" => {
            "name" => "brutalismbot",
          },
          "object" => {
            "key" => "data/v1/posts/year%3D2019/month%3D2019-04/day%3D2019-04-20/1555799559.json",
          },
        },
      },
    ],
  }
  runtest "MIRROR", -> { mirror event: event, context: nil }
end

desc 'lambda.uninstall'
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
  runtest "UNINSTALL", -> { uninstall event:event, context:nil }
end

task :default => [:test, :cache, :mirror, :uninstall]
