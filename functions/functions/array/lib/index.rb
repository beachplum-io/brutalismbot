require 'yake'

handler :array do |event|
  pop  = -> (arr) { arr.pop  event['pop']  if event['pop'] }
  push = -> (arr) { arr.push event['push'] if event['push'] }
  event['array'].tap(&pop).tap(&push)
end
