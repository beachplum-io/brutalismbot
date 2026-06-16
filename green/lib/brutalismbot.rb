# frozen_string_literal: true

require 'aws-sdk-dynamodb'

require_relative 'brutalismbot/cursor'
require_relative 'brutalismbot/table'

module Brutalismbot
  extend Table
end
