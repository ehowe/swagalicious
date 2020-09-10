class Hash
  def deep_merge!(other_hash)
    self.merge(other_hash) do |key, oldval, newval|
      oldval = oldval.to_hash if oldval.respond_to?(:to_hash)
      newval = newval.to_hash if newval.respond_to?(:to_hash)
      oldval.class.to_s == "Hash" && newval.class.to_s == "Hash" ? oldval.deep_merge(newval) : newval
    end
  end

  def slice(*keep_keys)
    h                                              = {}
    keep_keys.each { |key| has_key?(key) && h[key] = fetch(key, nil) }
    h
  end

  def except(*less_keys)
    slice(*keys - less_keys)
  end
end
