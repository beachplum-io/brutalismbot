RSpec.describe :reddit do
  before { require_relative '../lib/reddit.rb' }

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
end
