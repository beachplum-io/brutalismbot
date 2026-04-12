require 'aws-sdk-cloudwatch'
require 'yake/logger'

module Aws
  module CloudWatch
    class Metrics
      include Yake::Logger

      def client
        @client ||= Client.new
      end

      def namespace
        @namespace ||= ENV.fetch('NAMESPACE', 'brutalismbot-blue')
      end

      def update_queue_size(value)
        params = {
          namespace:,
          metric_data: [{
            metric_name: 'QueueSize',
            unit: 'Count',
            value:,
            dimensions: [{
              name: 'QueueName',
              value: 'r/brutalism'
            }]
          }]
        }
        logger.info("cloudwatch:PutMetricData #{params.to_json}")
        client.put_metric_data(**params)
      end
    end
  end
end
