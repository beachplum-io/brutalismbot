RSpec.describe :http do
  let :url     do 'https://example.com/' end
  let :json    do { fizz: 'buzz' }.to_json end
  let :form    do { fizz: 'buzz' }.to_form end
  let :body    do { ok:true }.to_json end
  let :headers do { 'content-length' => body.length.to_s, 'content-type' => 'application/json' } end

  before { require_relative '../lib/http' }

  context :get do
    let :event do { url: url } end
    let :res   do OpenStruct.new code: '200', body: body, each_header: headers.each end

    it 'should execute a GET request' do
      expect_any_instance_of(Net::HTTP).to receive(:request).with(an_instance_of(Net::HTTP::Get), nil).and_return(res)
      expect(get event: event).to eq statusCode: '200', body: body, headers: headers
    end
  end

  context :head do
    let :event do { url: url } end
    let :res   do OpenStruct.new code: '200', body: nil, each_header: headers.each end

    it 'should execute a HEAD request' do
      expect_any_instance_of(Net::HTTP).to receive(:request).with(an_instance_of(Net::HTTP::Head), nil).and_return(res)
      expect(head event: event).to eq statusCode: '200', body: nil, headers: headers
    end
  end

  context :post do
    let :event do { url: url, body: body } end
    let :res   do OpenStruct.new code: '200', body: body, each_header: headers.each end

    it 'should execute a POST request' do
      expect_any_instance_of(Net::HTTP).to receive(:request).with(an_instance_of(Net::HTTP::Post), {ok:true}.to_json).and_return(res)
      expect(post event: event).to eq statusCode: '200', body: body, headers: headers
    end
  end
end
