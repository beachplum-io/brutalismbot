# frozen_string_literal: true

require_relative 'post'

module Reddit
  class Listing
    include Enumerable

    def self.load(filepath)
      new JSON.parse File.read(filepath)
    end

    def initialize(data)
      @data = data
    end

    def inspect
      "#<#{self.class}>"
    end

    def each
      @data.dig('data', 'children').each do |child|
        post = Post.new child['data']
        yield post if post.media_urls.any?
      end
    end

    def all
      to_a
    end

    def latest(start = nil)
      after(start).reject(&:is_self?).sort_by(&:created_utc)
    end

    def after(start = nil)
      select { |post| start.nil? || post.created_utc > start }
    end

    def between(start = nil, stop = nil)
      select { |post| after(start) && before(stop) }
    end

    def before(stop = nil)
      select { |post| stop.nil? || post.created_utc <= stop }
    end
  end
end
