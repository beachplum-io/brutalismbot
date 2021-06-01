require "json"

require "aws-sdk-cloudwatch"
require "yake/logger"

module Reddit
  class Metrics
    include Yake::Logger

    def initialize(client = nil)
      @client = client || Aws::CloudWatch::Client.new
    end

    def publish(**params)
      logger.info("CloudWatch:PutMetricData #{ params.to_json }")
      @client.put_metric_data(**params).to_h
    end
  end
end
