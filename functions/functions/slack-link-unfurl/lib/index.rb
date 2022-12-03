require 'yake'
require 'yake/support'

def header(text)
  { type: 'header', text: plain_text(text) }
end

def mrkdwn(text)
  { type: 'mrkdwn', text: text }
end

def plain_text(text, emoji: true)
  { type: 'plain_text', text: text, emoji: emoji }
end

def section(text, accessory: nil)
  { type: 'section', text: text, accessory: accessory }.compact
end

def actions(*elements)
  { type: 'actions', elements: elements }
end

def fields(*items)
  { type: 'section', fields: items }
end

def context_block(*elements)
  { type: 'context', elements: elements }
end

def image(url, alt: nil, title: nil)
  { type: 'image', alt_text: alt.to_s, image_url: url, title: title }.compact
end

def button(text, action_id:nil, style:nil, url:nil, value:nil)
  {
    type:      'button',
    action_id: action_id,
    style:     style,
    text:      plain_text(text),
    url:       url,
    value:     value
  }.compact
end

def bold(text)
  "*#{text}*"
end

def italic(text)
  "_#{text}_"
end

def link(url, text)
  "<#{url}|#{text}>"
end

def blocks(*blocks)
  { blocks: blocks }
end

PROJECT_NAME = 'Keychron K8 Pro'
PROJECT_DESC = 'A multi-functional, wireless, intuitive, mechanical keyboard that pairs with Mac and PC'
PROJECT_IMG  = 'https://ksr-ugc.imgix.net/assets/036/502/695/fda736cff6797010e39ebee6e056c2a7_original.jpg?ixlib=rb-4.0.2&crop=faces&w=1024&h=576&fit=crop&v=1646107875&auto=format&frame=1&q=92&s=5a0daccd0312060a5340ba316a18be3b'
PROJECT_URL  = 'https://www.kickstarter.com/projects/keytron/keychron-k8-pro-qmk-via-wireless-mechanical-keyboard'
FAVICON      = 'https://kickstarter.com/favicon.png'
UNFURL = blocks(
  header(PROJECT_NAME),
  section(mrkdwn(PROJECT_DESC)),
  image(PROJECT_IMG, alt: PROJECT_NAME, title: plain_text('By Keychron')),
  context_block(
    image(FAVICON, alt: 'ksr'), mrkdwn("*Days Left*\t6"),
    image(FAVICON, alt: 'ksr'), mrkdwn("*Pledged*\t$42,000"),
    image(FAVICON, alt: 'ksr'), mrkdwn("*Goal*\t$50,000"),
  ),
  #fields(mrkdwn("*Goal*\t$50,000"), mrkdwn("*Backers*\t2,643")),
  #fields(mrkdwn("*Pledged*\t$42,123\n████████\t\t\t84%")),
  actions(
    button('Watch Project', url: PROJECT_URL),
    button('Back Project', style: 'primary', url: PROJECT_URL)
  )
)

handler :unfurl do |event|
  unfurl = -> (link) do { link['url'] => UNFURL } end

  {
    channel:   event.dig('event', 'channel'),
    ts:        event.dig('event', 'message_ts'),
    source:    event.dig('event', 'source'),
    unfurl_id: event.dig('event', 'unfurl_id'),
    unfurls:   event.dig('event', 'links').map(&unfurl).reduce(&:merge).to_json
  }
end

puts UNFURL.to_json if __FILE__ == $0
