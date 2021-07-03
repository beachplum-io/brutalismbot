require_relative '../lib/dynamodb.rb'

logging :off

RSpec.describe :dynamodb do
  context 'query' do
    let :event do
      {
        TableName: 'Fizz',
        ProjectionExpression: 'Buzz',
        KeyConditionExpression: '#Jazz = :Fuzz',
        ExpressionAttributeNames: { '#Jazz' => 'Jazz' },
        ExpressionAttributeValues: { ':Fuzz' => 'Fuzz' }
      }
    end

    it 'should execute a query' do
      expect(DYNAMODB).to receive(:query).with event.transform_keys(&:snake_case)
      query event: event
    end
  end
end
