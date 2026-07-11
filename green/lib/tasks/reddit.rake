# frozen_string_literal: true

require_relative '../brutalismbot'
require_relative '../reddit'

namespace :reddit do
  desc 'Sync listing with DynamoDB'
  task :sync do
    # Open JSON in browser
    sh %{open 'https://old.reddit.com/r/brutalism/new.json?limit=100&raw_json=1'}

    # Wait for copy
    $stderr.write 'press RETURN when contents copied to clipboard... '
    $stdin.gets

    # Paste into file
    sh %{pbpaste > new.json}

    # Load
    listing = Reddit::Listing.load('new.json')
    items   = listing.latest(Brutalismbot.latest).map(&:to_item)
    items.each { |item| Brutalismbot << item }
  end

  desc 'Run screen workflow'
  task :screen do
    sh %{aws stepfunctions start-execution --state-machine-arn arn:aws:states:us-west-2:556954866954:stateMachine:brutalismbot-green-reddit-screen | jq}
  end
end
