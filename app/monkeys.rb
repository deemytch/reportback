# Разные заплатки и улучшения на библиотечные классы

class Hash
  def add_keysym_from(h)
    h.each{|k,v| self[ k.to_sym ] = v }
    self
  end
  def present?; ! self.empty?; end

  def symbolize_keys
    z = {}
    self.each do |k,v|
      z[ k.is_a?(String) ? k.to_sym : k ] = 
          case v
          when Hash then v.symbolize_keys
          when Array then v.symbolize_hashes
          else
            Marshal.load(Marshal.dump(v))
          end
    end
    z
  end

  def deep_merge(src)
    dst = self.dup
    dst.merge(src){|k, o1, o2|
      if o1.is_a?(o2.class) && o1.respond_to?(:deep_merge)
        o1.deep_merge(o2)
      else # classes mismatch or simple type
        o2.dup
      end
    }
  end

  def keys?(*list)
    self.keys.include?(*list)
  end
end

class Array
  alias :super_include? :include?
  alias :present? :any?

  def include?(*list)
    list.count == 1 ? super_include?(list.first) : ( self & list ).count == list.count
  end
  def symbolize_hashes
    z = []
    self.each do |i|
      z << case i
        when Array then i.symbolize_hashes
        when Hash then i.symbolize_keys
        else
          Marshal.load(Marshal.dump(i))
        end
    end
    return z
  end
end

class String
  def like_number?
    x = self.gsub /^([+-]?)\./, "#{ $1 }0."
    !! ( x =~ /^[-+]?(\d+)(\.\d+(e[-+]?\d+)?)?$/ )
  end
  def present?; ! empty?; end
  def from_json
    self.force_encoding('UTF-8')
    JSON.parse(self).symbolize_keys rescue {}
  end
  def to_a; [self]; end
end

class NilClass
  def empty?; true; end
  def present?; false; end
  def dig(*args); self; end
  def to_a; []; end
end
class Object; def present?; ! nil?; end end
class Numeric
  def present?; true; end
  def to_a; [self]; end
end

module ApiHelper
  def self.new_request_id
    (Time.now.to_f * 1000000).to_i.to_s.freeze
  end
end

class Thread
  def wait_for_key( k, tmout = Cfg.app.tmout.service )
    start_time = Time.now
    sleep 0.01 until Thread.current.key?(k) || Time.now - start_time >= tmout
    return Time.now - start_time < tmout
  end
end
