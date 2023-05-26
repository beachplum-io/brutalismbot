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

  def self.actions(execution_id)
    { type: 'actions', elements: [ Action.dismiss, Action.reject(execution_id) ] }
  end
end

class Action
  def self.dismiss
    {
      action_id: 'delete_me',
      type:      'button',
      value:     'approve',
      text:      'Dismiss'.plain_text,
    }
  end

  def self.reject(execution_id)
    {
      action_id: 'reject',
      type:      'button',
      style:     'danger',
      value:     execution_id,
      text:      'Reject'.plain_text,
      confirm: {
        style:   'danger',
        title:   'Are you sure?'.plain_text,
        text:    'This cannot be undone.'.plain_text,
        confirm: 'Reject'.plain_text,
        deny:    'Cancel'.plain_text,
      }
    }
  end
end

def blocks(text, link, media, execution_id)
  [
    *Block.images(text, media),
    Block.context(text, link),
    Block.actions(execution_id),
  ]
end
