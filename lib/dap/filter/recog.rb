require 'recog'

module Dap
module Filter

class FilterRecog
  include Base

  def process(doc)
    self.opts.each_pair do |k,v|
      next unless doc.has_key?(k)
      match = Recog::Nizer.match(v, doc[k])
      next unless match
      match.each_pair do |ok, ov|
        doc["#{k}.recog.#{ok}"] = ov.to_s
      end
    end
   [ doc ]
  end
end

end
end