RSpec.describe :slack do
  before { require_relative '../lib/slack.rb' }

  context 'transform' do
    let :event do
      {
        name:     't3_abcdefg',
        permalink: '<path>',
        title:     '<title>',
      }
    end

    let :exp do
      {
        text: '<title>',
        blocks: [
          {
            type: 'context',
            elements: [
              {
                text: '<https://www.reddit.com<path>|<title>>',
                type: 'mrkdwn'
              }
            ]
          }
        ]
      }
    end

    it 'should transform a post' do
      expect(transform event:event).to eq exp
    end
  end
end
