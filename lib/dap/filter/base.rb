module Dap
module Filter

module Base
  attr_accessor :name, :opts

  def initialize(args)
    self.opts = {}
    args.each do |arg|
        k,v = arg.split("=", 2)
        self.opts[k] = v
    end
    self.name = Dap::Factory.name_from_class(self.class)
  end

  def process(doc)
    raise RuntimeError, "No process() method defined for filter #{self.name}"
  end

end

module BaseDecoder
  include Base
  def process(doc)
    self.opts.each_pair do |k,v|
      next unless doc.has_key?(k)
      info = decode(doc[k]) || {}
      info.each_pair do |x,y|
        doc[ "#{k}.#{x}" ] = y
      end
    end
   [ doc ]
  end
end

end
end