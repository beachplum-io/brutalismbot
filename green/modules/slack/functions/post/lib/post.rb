require 'erb'
require 'json'
require 'net/http'
require 'yaml'

require 'yake/logger'

Post = Struct.new(:url, :token, :channel, :text, :link, :media) do
  include Yake::Logger

  Image = Struct.new(:url, :title, :alt)

  def self.template
    @template ||= ERB.new(File.read(File.expand_path('post.yml.erb', File.dirname(__FILE__))))
  end

  def images
    @images ||= media.map(&:first).each_with_index.map do |m, i|
      url   = m['u']
      alt   = text
      title = media.one? ? 'r/brutalism' : "r/brutalism [#{i + 1}/#{media.count}]"
      Image.new(url:, alt:, title:)
    end
  end

  def body
    @body ||= YAML.safe_load(Post.template.result(binding))
  end

  def headers
    @headers ||= {
      'authorization' => "Bearer #{token}",
      'content-type'  => 'application/json; charset=utf-8',
    }
  end

  def request
    { method: 'POST', url:, headers:, body: }
  end

  def response
    uri     = URI(url)
    use_ssl = uri.scheme == 'https'
    Net::HTTP.start(uri.host, uri.port, use_ssl:) do |http|
      req = Net::HTTP::Post.new(uri.path, **headers)
      res = http.request(req, body.to_json)

      {
        statusCode: res.code,
        headers:    res.each_header.to_h,
        body:       res.body
      }
    end
  end
end
