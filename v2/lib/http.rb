require "net/http"

require "yake"

handler :post do |event|
  url, headers, body = event.slice("url", "headers", "body").values
  uri = URI(url)
  res = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
    req = Net::HTTP::Post.new(uri.path, **headers)
    req.body = body
    http.request(req)
  end

  {
    statusCode: res.code,
    body:       res.body,
    headers:    res.each_header.sort.to_h,
  }
end
