require 'json'

require 'aws-sdk-s3'
require 'aws-sdk-states'
require 'mail'
require 'yake'

MAIL_RETURN_PATH  ||= '<no-reply@brutalismbot.com>'
MAIL_FROM         ||= "Brutalismbot Help #{MAIL_RETURN_PATH}"
MAIL_TO           ||= ENV['MAIL_TO'].to_s
STATE_MACHINE_ARN ||= ENV['STATE_MACHINE_ARN'].to_s

S3     ||= Aws::S3::Client.new
STATES ||= Aws::States::Client.new

handler :mail do |event|
  event['Records'].map do |record|
    # Get message from S3
    message = JSON.parse record.dig 'Sns', 'Message'
    bucket  = message.dig 'receipt', 'action', 'bucketName'
    key     = message.dig 'receipt', 'action', 'objectKey'
    object  = S3.get_object bucket: bucket, key: key
    body    = object.body.read.force_encoding('ISO-8859-1').encode('UTF-8', replace: nil)

    # Massage message for SES
    mail             = Mail.new body
    mail.to          = MAIL_TO
    mail.reply_to    = mail.from
    mail.from        = MAIL_FROM
    mail.return_path = MAIL_RETURN_PATH

    # Start Execution
    input = {
      ToAddresses: mail.to,
      FromEmailAddress: mail.from.first,
      ReplyToAddresses: mail.reply_to,
      Destination: { ToAddresses: mail.to },
      Content: {
        Simple: {
          Subject: { Data: mail.subject, Charset: 'UTF-8'},
          Body: { Text: { Data: mail.body.to_s, Charset: 'UTF-8' } },
        }
      }
    }
    STATES.start_execution(
      state_machine_arn: STATE_MACHINE_ARN,
      input:             input.to_json
    )
  end
end
