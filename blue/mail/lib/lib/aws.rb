require 'aws-sdk-s3'
require 'aws-sdk-ssm'
require 'aws-sdk-states'

require 'yake/logger'
require 'yake/support'

module Aws
  class S3::Client
    include Yake::Logger

    def get_mail_body(record)
      message = record.dig('Sns', 'Message').to_h_from_json
      bucket  = message.dig('receipt', 'action', 'bucketName')
      key     = message.dig('receipt', 'action', 'objectKey')
      params  = { bucket: bucket, key: key }
      logger.info("s3:GetObject #{ params.to_json }")
      object = get_object(**params)
      object.body.read.force_encoding('ISO-8859-1').encode('UTF-8', replace: nil)
    end
  end

  class SSM::Client
    include Yake::Logger

    def export(name)
      params = { name: name }
      logger.info("ssm:GetParameter #{ params.to_json }")
      get_parameter(**params).parameter.tap do |param|
        key = File.basename(param.name)
        val = param.value
        ENV[key] = val
      end
    end
  end

  class States::Client
    include Yake::Logger

    def forward_mail(state_machine_arn, mail)
      params = {
        state_machine_arn: state_machine_arn,
        input: { Content: { Raw: { Data: mail.to_s } } }.to_json
      }
      logger.info("states:StartExecution #{ params.to_json }")
      start_execution(**params)
    end
  end
end
