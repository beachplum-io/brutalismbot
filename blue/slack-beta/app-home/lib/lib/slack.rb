module Slack
  module Action
    def self.method_missing(m, *args, **kwargs)
      { type: m.to_s, **kwargs.compact }.compact
    end
  end

  module Block
    def self.method_missing(m, *args, **kwargs)
      { type: m.to_s, **kwargs.compact }.compact
    end
  end

  module String
    def bold() wrap('*') end
    def code() wrap('`') end
    def code_block() wrap('```') end
    def emoji() wrap(':') end
    def encode_conversation() "<##{to_s}>" end
    def encode_link(url) "<#{url}|#{to_s}>" end
    def encode_user() "<@#{to_s}>" end
    def italic() wrap('_') end
    def mrkdwn() { type: 'mrkdwn', text: to_s } end
    def option(value = nil, **params) { value: (value || self).to_s, text: to_s.plain_text, **params.compact } end
    def option_group(options, **params) { label: to_s.plain_text, options: options, **params.compact } end
    def plain_text(**params) { type: 'plain_text', text: to_s, **params.compact } end
    def wrap(string) "#{string}#{to_s}#{string}" end
  end
end

::String.include(Slack::String)
