require 'net/http'

require 'yake'

require_relative 'lib/common'

def request(klass, event)
  uri = URI event[:url]
  ssl = uri.scheme == 'https'
  hed = event[:headers] || {}
  req = klass.new(uri, **hed)
  Net::HTTP.start(uri.host, uri.port, use_ssl: ssl) do |http|
    res = http.request req, event[:body]

    {
      statusCode: res.code,
      headers:    res.each_header.to_h,
      body:       res.body
    }
  end
end

handler :get  do |event| request Net::HTTP::Get,  event.symbolize_names end
handler :head do |event| request Net::HTTP::Head, event.symbolize_names end
handler :post do |event| request Net::HTTP::Post, event.symbolize_names end
