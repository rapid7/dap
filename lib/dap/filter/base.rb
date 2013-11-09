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

end
end