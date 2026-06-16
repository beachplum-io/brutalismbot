# frozen_string_literal: true

module Brutalismbot
  class Cursor
    include Comparable

    def initialize(table)
      @table = table
    end

    def key
      @key ||= { Id: 'r/brutalism', Kind: 'cursor' }
    end

    def item
      @item ||= @table.get_item(key:).item
    end

    def <=>(other)
      Time.parse(item['CreatedUtc']) <=> other
    end
  end
end
