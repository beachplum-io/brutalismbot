require 'yake'

require_relative 'lib/home'

HOME ||= Home.new

handler(:home) { HOME.view }
