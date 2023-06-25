require 'json'

require 'mail'
require 'yake'

require_relative 'lib/aws'

MAIL_RETURN_PATH  ||= '<no-reply@brutalismbot.com>'
MAIL_FROM         ||= "Brutalismbot Help #{MAIL_RETURN_PATH}"
MAIL_TO_PARAM     ||= ENV['MAIL_TO_PARAM']
STATE_MACHINE_ARN ||= ENV['STATE_MACHINE_ARN']

S3     ||= Aws::S3::Client.new
SSM    ||= Aws::SSM::Client.new
STATES ||= Aws::States::Client.new

SSM.export(MAIL_TO_PARAM)
MAIL_TO ||= ENV['MAIL_TO']

handler :mail do |event|
  event['Records'].map do |record|
    # Get message from S3
    body = S3.get_mail_body(record)

    # Massage message for SES
    mail             = Mail.new(body)
    mail.to          = MAIL_TO
    mail.reply_to    = mail.from
    mail.from        = MAIL_FROM
    mail.return_path = MAIL_RETURN_PATH

    # Start Execution
    STATES.forward_mail(STATE_MACHINE_ARN, mail)
  end
end
