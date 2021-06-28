require "json"
require "time"

class Hash
  def symbolize_names() JSON.parse to_json, symbolize_names: true end
end

class Integer
  def days() hours * 24 end
  def hours() minutes * 60 end
  def minutes() seconds * 60 end
  def seconds() self end
  def utc() UTC.at(self) end
end

class String
  def camel_case() split(/_/).map(&:capitalize).join end
  def snake_case() gsub(/([a-z])([A-Z])/, '\1_\2').downcase end
  def to_h_from_json(**params) JSON.parse(self, **params) end
end

class Symbol
  def camel_case() to_s.camel_case.to_sym end
  def snake_case() to_s.snake_case.to_sym end
end

class UTC < Time
  def self.at(...) super.utc end
  def self.now() super.utc end
end
