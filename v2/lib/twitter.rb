require "yake"

handler :transform do |event|
  # Extract info from event
  media = event["Media"]
  title = event["Title"]
  perma = File.join "https://reddit.com/", event["Permalink"]

  # Get status
  max    = 279 - perma.length
  status = title.length <= max ? title : "#{ title[0..max] }…" + "\n#{ perma }"

  # Zip status with media
  size    = (media.count % 4).between?(1, 2) ? 3 : 4
  updates = media.each_slice(size).zip([status]).map do |media, status|
    { Status: status, Media: media }.compact
  end

  # Return updates
  { Updates: updates, Count: updates.count }
end
