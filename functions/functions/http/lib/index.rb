require 'json'
require 'uri'

require 'yake'

handler :http do |event|
  to_s    = -> (obj) { obj.is_a?(Hash) ? obj.to_json : obj.to_s }
  uri     = URI event['url']
  body    = event['body']
  headers = event['headers'] || {}
  method  = event['method'].capitalize
  use_ssl = uri.scheme == 'https'
  request = Net::HTTP.const_get(method).new(uri, **headers)
  result  = Net::HTTP.start(uri.host, uri.port, use_ssl: use_ssl) do |http|
    http.request request, body&.then(&to_s)
  end

  {
    statusCode: result.code,
    headers:    result.each_header.to_h,
    body:       result.body
  }
end
