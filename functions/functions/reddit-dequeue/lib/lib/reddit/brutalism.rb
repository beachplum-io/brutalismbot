require 'open-uri'
require 'time'

require 'aws-sdk-dynamodb'
require 'yake/logger'
require 'yake/support'

require_relative 'post'

module Reddit
  class Brutalism
    include Enumerable
    include Yake::Logger

    attr_reader :headers, :table

    TABLE_NAME = ENV['TABLE_NAME']        || 'Brutalismbot'
    USER_AGENT = ENV['REDDIT_USER_AGENT'] || 'Brutalismbot'

    def initialize(resource = :new, table = nil, **headers)
      @uri     = URI "https://www.reddit.com/r/brutalism/#{ resource }.json?raw_json=1"
      @table   = table || Aws::DynamoDB::Table.new(name: TABLE_NAME)
      @headers = { 'user-agent' => USER_AGENT, **headers }
    end

    def each
      logger.info("GET #{ @uri }")
      URI.open(@uri, **@headers) do |stream|
        stream.read.to_h_from_json.symbolize_names.dig(:data, :children).each do |child|
          yield Post.new child[:data]
        end
      end
    end

    def all
      to_a
    end

    def latest
      params = {
        key: { GUID: 'STATS/MAX', SORT: 'REDDIT/POST' },
        projection_expression: 'CREATED_UTC'
      }
      logger.info("GET ITEM #{ params.to_json }")
      item  = @table.get_item(**params).item || {}
      start = Time.parse item.fetch 'CREATED_UTC', '1970-01-01T00:00:00Z'
      after(start).reject(&:is_self?).sort_by(&:created_utc)
    end

    def after(start)
      select { |post| post.created_utc > start }
    end

    def between(start, stop)
      select { |post| post.created_utc > start && post.created_utc < stop }
    end

    def before(stop)
      select { |post| post.created_utc < stop }
    end

    class << self
      def hot(table = nil, **headers)
        new(:hot, table, **headers)
      end

      def top(table = nil, **headers)
        new(:top, table, **headers)
      end
    end
  end
end
