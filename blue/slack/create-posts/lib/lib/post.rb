require 'erb'
require 'json'
require 'yaml'

class Post < Struct.new('Post', :channel, :text, :link, :images)
  class Image < Struct.new('Image', :url, :title, :alt) ; end

  TEMPLATE = File.read(File.expand_path('post.yml.erb', File.dirname(__FILE__)))

  def self.images(text, media)
    media.map(&:first).each_with_index.map do |m, i|
      url   = m['u']
      title = media.one? ? 'r/brutalism' : "r/brutalism [#{i + 1}/#{media.count}]"
      Image.new(url: url, alt: text, title: title)
    end
  end

  def to_h
    body = ERB.new(TEMPLATE).result(binding)
    YAML.safe_load(body)
  end

  def to_json
    to_h.to_json
  end
end
