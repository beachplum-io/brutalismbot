class String
  def link(url) "<#{url}|#{self}>" end
  def mrkdwn() { type: 'mrkdwn', text: self } end
  def plain_text(emoji: nil) { type: 'plain_text', text: self, emoji: emoji }.compact end
end

class Block
  def self.context(text, link)
    { type: 'context', elements: [text.link(link).mrkdwn] }
  end

  def self.image(url, alt, title)
    { type: 'image', image_url: url, alt_text: alt, title: title.plain_text }
  end

  def self.images(text, media)
    media.map(&:first).each_with_index.map do |m,i|
      image(m['u'], text, "/r/brutalism [#{i + 1}/#{media.count}]")
    end
  end
end

def blocks(text, link, media)
  [ *Block.images(text, media), Block.context(text, link) ]
end
