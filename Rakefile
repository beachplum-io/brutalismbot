ENV["DRYRUN"] = "1"
require_relative "./lambda"
LAST_SEEN = BRUTALISMBOT.subreddit.posts(:new, limit: 2).last.fullname

def runtest(name, func)
  puts "\n=> #{name}"
  puts func.call
end

desc 'lambda.test'
task :test do
  runtest "TEST", -> { test event: nil }
end

desc 'lambda.install'
task :authorize do
  event = {"Records" => [{"Sns" => {"Message" => Brutalismbot::Auth.stub.to_json}}]}
  runtest "AUTHORIZE", -> { authorize event: event }
end

desc 'lambda.cache'
task :cache do
  runtest "CACHE", -> { cache }
end

desc 'lambda.mirror'
task :mirror do
  key   = BRUTALISMBOT.posts.key_for BRUTALISMBOT.posts.last
  event = {
    "Records" => [
      {
        "s3" => {
          "bucket" => {
            "name" => "brutalismbot",
          },
          "object" => {
            "key" => URI.escape(key),
          },
        },
      },
    ],
  }
  runtest "MIRROR", -> { mirror event: event }
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

task :default => [:test, :authorize, :cache, :mirror, :uninstall]
