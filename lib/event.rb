module Event
  class RecordCollection < Hash
    include Enumerable

    def each
      puts "EVENT #{to_json}"
      dig("Records").each{|x| yield x }
    end
  end

  class SNS < RecordCollection
    def each
      super do |record|
        yield JSON.parse record.dig("Sns", "Message")
      end
    end
  end

  class S3 < RecordCollection
    def each
      super do |record|
        bucket = URI.unescape record.dig("s3", "bucket", "name")
        key    = URI.unescape record.dig("s3", "object", "key")
        yield bucket: bucket, key: key
      end
    end
  end
end
