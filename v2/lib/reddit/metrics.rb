require "json"

require "aws-sdk-cloudwatch"
require "yake/logger"

module Reddit
  class Metrics
    include Yake::Logger

    def initialize(client = nil)
      @client = client || Aws::CloudWatch::Client.new
    end

    def put_metric_data(**params)
      logger.info("CloudWatch:PutMetricData #{ params.to_json }")
      params.tap { @client.put_metric_data(**params) }
    end
  end
end
