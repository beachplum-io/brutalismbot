require_relative '../lib/reddit.rb'

logging :off

RSpec.describe :reddit do
  context 'dequeue' do
    let :post do
      Reddit::Post.new do |post|
        post.created_utc = 1234567890
        post.name        = 't3_abcdefg'
        post.permalink   = '<path>'
        post.title       = '<title>'
      end
    end

    let :res do
      OpenStruct.new read: { data: {
        children: 3.times.map do { data: post.to_h } end
      } }.to_json
    end

    it 'should dequeue the next post' do
      expect(URI).to receive(:open).and_yield res
      expect(R_BRUTALISM.table).to receive(:get_item).and_return OpenStruct.new
      expect(dequeue).to eq(
        QueueSize: 2,
        NextPost: {
          CREATED_UTC: '2009-02-13T23:31:30Z',
          DATA:        post.to_h,
          NAME:        't3_abcdefg',
          PERMALINK:   '<path>',
          TITLE:       '<title>',
          TTL:         1234567890 + TTL
        }
      )
    end
  end

  context 'metrics' do
    let :event do { 'namespace' => 'RSpec', 'metric_data' => metric_data } end
    let :metric_data do [] end

    it 'should send metrics' do
      expect(METRICS.client).to receive(:put_metric_data).with(event.symbolize_names).and_return({})
      expect(metrics event:event).to eq event.symbolize_names
    end
  end
end
