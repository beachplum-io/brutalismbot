class UTC < Time
  def self.hours_ago(n)
    now - n * 60 * 60
  end

  def self.epoch
    at(0).utc
  end

  def self.now
    super.utc
  end
end
