module Dap
module Utils
module Misc

  def self.flatten_hash(h)
    ret = {}
    h.each_pair do |k,v|
      next unless k
      if v.is_a?(Hash)
        flatten_hash(v).each_pair do |fk,fv|
          ret["#{k}.#{fk}"] = fv.to_s
        end
      else
        ret[k] = v.to_s
      end
    end
    ret
  end

end
end
end
