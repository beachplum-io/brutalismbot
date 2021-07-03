RSpec.describe :tweet do
  before { require_relative '../lib/tweet' }

  context 'transform' do
    let :preview do
      {
        name:     't3_abcdefg',
        permalink: '/<path>',
        title:     '<title>',
        preview:  {
          images: [
            {
              resolutions: [],
              source: {
                url:    'https://preview.redd.it/',
                width:  1024,
                height: 1024,
              }
            }
          ]
        }
      }
    end

    let :gallery do
      {
        name:       't3_abcdefg',
        permalink:  '/<path>',
        title:      '<title>',
        is_gallery: true,
        media_metadata: {
          '<image-id>': {
            id: '<image-id>',
            status: 'valid',
            e: "Image",
            m: "image/jpg",
            s: { y:1024, x:1024, u:'https://preview.redd.it/' },
            p: [],
          }
        }
      }
    end

    let :exp do
      {
        count: 1,
        updates: [
          {
            status: "<title>\nhttps://www.reddit.com/<path>",
            media: [ "https://preview.redd.it/" ]
          }
        ]
      }
    end

    it 'should transform a preview post' do
      expect(transform event:preview).to eq exp
    end

    it 'should transform a gallery post' do
      expect(transform event:gallery).to eq exp
    end
  end

  context 'post' do
    it 'should post a tweet' do
    end
  end
end
