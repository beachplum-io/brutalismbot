# frozen_string_literal

module Brutalismbot
  module Table
    def table
      @table ||= Aws::DynamoDB::Table.new('brutalismbot-green')
    end

    def cursor
      @cursor ||= Cursor.new(table)
    end

    def <<(item)
      $stderr.write("dynamodb:PutItem #{item.slice(:Id, :Kind).to_json}\n")
      table.put_item(item:)
    end
  end
end
